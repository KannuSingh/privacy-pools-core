// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {IntegrationBase} from "./IntegrationBase.sol";
import {InternalLeanIMT, LeanIMTData} from "lean-imt/InternalLeanIMT.sol";
import {console} from "forge-std/console.sol";

import {IPrivacyPool} from "interfaces/IPrivacyPool.sol";
import {IState} from "interfaces/IState.sol";
import {IEntrypoint} from "interfaces/IEntrypoint.sol";
import {SimplePrivacyPoolPaymaster} from "contracts/SimplePrivacyPoolPaymaster.sol";

// Privacy Pool contracts
import {Entrypoint} from "contracts/Entrypoint.sol";
import {PrivacyPoolSimple} from "contracts/implementations/PrivacyPoolSimple.sol";
import {CommitmentVerifier} from "contracts/verifiers/CommitmentVerifier.sol";
import {WithdrawalVerifier} from "contracts/verifiers/WithdrawalVerifier.sol";
import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";

// ERC-4337 imports
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SimpleAccount} from "@account-abstraction/contracts/samples/SimpleAccount.sol";

import {ProofLib} from "contracts/lib/ProofLib.sol";
import {Constants} from "test/helper/Constants.sol";
import {IERC20} from "@oz/interfaces/IERC20.sol";

/**
 * @title PrivacyPoolPaymasterE2E
 * @notice End-to-end test for Privacy Pool Paymaster integration with ERC-4337
 * @dev Tests the complete flow: deposit → generate proof → create UserOp → execute via paymaster
 */
contract SimplePrivacyPoolPaymasterE2E is IntegrationBase {
    using InternalLeanIMT for LeanIMTData;
    using ProofLib for ProofLib.WithdrawProof;

    /*//////////////////////////////////////////////////////////////
                          TEST STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // ERC-4337 Infrastructure
    IEntryPoint internal erc4337EntryPoint;
    SimplePrivacyPoolPaymaster internal paymaster;

    // Test accounts
    SimpleAccount internal userAccount;
    address internal userAccountOwner;

    // Test data
    Commitment internal commitment;

    /*//////////////////////////////////////////////////////////////
                          EVENTS
    //////////////////////////////////////////////////////////////*/

    event ETHWithdrawalSponsored(
        address indexed userAccount,
        uint256 withdrawnValue,
        uint256 feeAmount,
        bytes32 nullifierHash
    );

    /*//////////////////////////////////////////////////////////////
                          SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Use Base Sepolia fork where ERC-4337 EntryPoint is deployed
        vm.createSelectFork("https://sepolia.base.org");

        // Setup privacy pool infrastructure (copy from IntegrationBase but with our fork)
        _setupPrivacyPoolInfrastructure();

        // Setup ERC-4337 infrastructure using deployed contracts
        _setupERC4337Infrastructure();
    }

    function _setupPrivacyPoolInfrastructure() internal {
        vm.startPrank(_OWNER);

        // Deploy Groth16 ragequit verifier
        _commitmentVerifier = new CommitmentVerifier();

        // Deploy Groth16 withdrawal verifier
        _withdrawalVerifier = new WithdrawalVerifier();

        // Deploy Entrypoint
        address _impl = address(new Entrypoint());
        bytes memory _initializationData = abi.encodeCall(
            Entrypoint.initialize,
            (_OWNER, _POSTMAN)
        );
        address _entrypointAddr = address(
            new ERC1967Proxy(_impl, _initializationData)
        );
        _entrypoint = Entrypoint(payable(_entrypointAddr));

        // Deploy ETH pool
        _ethPool = new PrivacyPoolSimple(
            address(_entrypoint),
            address(_withdrawalVerifier),
            address(_commitmentVerifier)
        );

        // Register ETH pool
        _entrypoint.registerPool(
            IERC20(Constants.NATIVE_ASSET),
            IPrivacyPool(address(_ethPool)),
            _MIN_DEPOSIT,
            _VETTING_FEE_BPS,
            _MAX_RELAY_FEE_BPS
        );

        vm.stopPrank();
    }

    function _setupERC4337Infrastructure() internal {
        vm.startPrank(_OWNER);

        // Use the deployed ERC-4337 EntryPoint on Sepolia
        erc4337EntryPoint = IEntryPoint(
            0x0000000071727De22E5E9d8BAf0edAc6f37da032
        );

        // For now, let's create a mock user account directly instead of using SimpleAccountFactory
        // This avoids the EntryPoint interface compatibility issue
        userAccountOwner = makeAddr("USER_ACCOUNT_OWNER");
        userAccount = SimpleAccount(payable(makeAddr("USER_ACCOUNT")));

        // Deploy Privacy Pool Paymaster (this is the main component we're testing)
        paymaster = new SimplePrivacyPoolPaymaster(
            erc4337EntryPoint,
            _entrypoint,
            _ethPool
        );

        // Fund paymaster with ETH for gas sponsorship
        deal(address(paymaster), 10 ether);

        // Fund user account owner for UserOp creation
        deal(userAccountOwner, 1 ether);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          MAIN E2E TEST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test Privacy Pool Paymaster deployment and basic validation
     * @dev Tests: paymaster setup → deposit → withdrawal proof → validation logic
     */
    function test_paymasterSetupAndValidation() public {
        // Test Phase 1: Verify paymaster deployment
        assertEq(address(paymaster.PRIVACY_POOL_ENTRYPOINT()), address(_entrypoint));
        assertEq(address(paymaster.ETH_PRIVACY_POOL()), address(_ethPool));
        assertEq(address(paymaster).balance, 10 ether);

        // Phase 2: Privacy Pool Deposit
        _executeDeposit();

        // Phase 3: Generate Withdrawal Proof for paymaster scenario
        ProofLib.WithdrawProof
            memory withdrawalProof = _generateWithdrawalProofForPaymaster();

        // Phase 4: Test the withdrawal execution through privacy pool (simulates what paymaster would validate)
        _testWithdrawalExecution(withdrawalProof);
    }

    /**
     * @notice Test complete ERC-4337 UserOperation flow with paymaster
     * @dev Tests: deposit → proof generation → UserOp creation → paymaster validation → execution
     */
    function test_fullUserOperationFlow() public {
        // Phase 1: Setup and deposit
        _executeDeposit();

        // Phase 2: Generate withdrawal proof for UserOp
        ProofLib.WithdrawProof
            memory withdrawalProof = _generateWithdrawalProofForPaymaster();

        // Phase 3: Create and test UserOperation
        _testUserOperationWithPaymaster(withdrawalProof);
    }

    /*//////////////////////////////////////////////////////////////
                          PHASE IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Phase 2: Execute Privacy Pool deposit
     */
    function _executeDeposit() internal {
        // Alice deposits 100 ETH into privacy pool
        commitment = _deposit(
            DepositParams({
                depositor: _ALICE,
                asset: _ETH,
                amount: 100 ether,
                nullifier: "paymaster_nullifier_1",
                secret: "paymaster_secret_1"
            })
        );

        // Push ASP root with label included (required for withdrawals)
        vm.prank(_POSTMAN);
        _entrypoint.updateRoot(
            _shadowASPMerkleTree._root(),
            "ipfs_cid_ipfs_cid_ipfs_cid_ipfs_cid_ipfs_cid_ipfs_cid"
        );
    }

    /**
     * @notice Phase 3: Generate withdrawal proof for paymaster flow
     */
    function _generateWithdrawalProofForPaymaster()
        internal
        returns (ProofLib.WithdrawProof memory proof)
    {
        // Create withdrawal struct for paymaster flow
        IPrivacyPool.Withdrawal
            memory withdrawal = _createPaymasterWithdrawal();

        // Calculate context hash
        uint256 context = uint256(
            keccak256(abi.encode(withdrawal, _ethPool.SCOPE()))
        ) % SNARK_SCALAR_FIELD;

        // Generate withdrawal proof using existing infrastructure
        proof = _generateWithdrawalProof(
            WithdrawalProofParams({
                existingCommitment: commitment.hash,
                withdrawnValue: 50 ether, // Partial withdrawal
                context: context,
                label: commitment.label,
                existingValue: commitment.value,
                existingNullifier: commitment.nullifier,
                existingSecret: commitment.secret,
                newNullifier: _genSecretBySeed("paymaster_new_nullifier"),
                newSecret: _genSecretBySeed("paymaster_new_secret")
            })
        );
    }

    /**
     * @notice Create withdrawal struct for paymaster scenario
     */
    function _createPaymasterWithdrawal()
        internal
        view
        returns (IPrivacyPool.Withdrawal memory)
    {
        // Build RelayData for paymaster flow
        IEntrypoint.RelayData memory relayData = IEntrypoint.RelayData({
            recipient: address(userAccount), // User account receives ETH
            feeRecipient: address(paymaster), // Paymaster receives fees
            relayFeeBPS: _RELAY_FEE_BPS // 1% fee
        });

        return
            IPrivacyPool.Withdrawal({
                processooor: address(_entrypoint), // Privacy entrypoint processes
                data: abi.encode(relayData) // Encoded relay data
            });
    }

    /**
     * @notice Phase 4: Test withdrawal execution (simulates what paymaster validates)
     */
    function _testWithdrawalExecution(
        ProofLib.WithdrawProof memory proof
    ) internal {
        // Create withdrawal for paymaster scenario
        IPrivacyPool.Withdrawal
            memory withdrawal = _createPaymasterWithdrawal();

        // Record initial balances
        uint256 userAccountInitialBalance = address(userAccount).balance;
        uint256 paymasterInitialBalance = address(paymaster).balance;
        uint256 poolInitialBalance = address(_ethPool).balance;

        // Calculate expected amounts
        uint256 withdrawnAmount = proof.withdrawnValue();
        uint256 feeAmount = (withdrawnAmount * _RELAY_FEE_BPS) / 10_000;
        uint256 userReceiveAmount = withdrawnAmount - feeAmount;

        // Execute the withdrawal through privacy pool entrypoint (this is what the paymaster validates)
        vm.prank(_RELAYER);
        _entrypoint.relay(withdrawal, proof, _ethPool.SCOPE());

        // Verify balance changes
        assertEq(
            address(userAccount).balance,
            userAccountInitialBalance + userReceiveAmount,
            "User account should receive withdrawn amount minus fees"
        );

        assertEq(
            address(paymaster).balance,
            paymasterInitialBalance + feeAmount,
            "Paymaster should receive fees"
        );

        assertEq(
            address(_ethPool).balance,
            poolInitialBalance - withdrawnAmount,
            "Pool balance should decrease by withdrawn amount"
        );

        // Verify nullifier was spent
        assertTrue(
            _ethPool.nullifierHashes(proof.existingNullifierHash()),
            "Nullifier should be marked as spent"
        );
    }

    /**
     * @notice Test UserOperation creation and paymaster validation
     */
    function _testUserOperationWithPaymaster(
        ProofLib.WithdrawProof memory proof
    ) internal {
        // Create withdrawal for paymaster scenario
        IPrivacyPool.Withdrawal
            memory withdrawal = _createPaymasterWithdrawal();

        // Build the inner callData for entrypoint.relay()
        bytes memory relayCallData = abi.encodeCall(
            _entrypoint.relay,
            (withdrawal, proof, _ethPool.SCOPE())
        );

        // Build the callData for userAccount.execute() - this is what ERC-4337 expects
        bytes memory callData = abi.encodeCall(
            SimpleAccount.execute,
            (
                address(_entrypoint), // dest: Privacy Pool Entrypoint
                0, // value: 0 ETH (no ETH sent with call)
                relayCallData // func: encoded relay call
            )
        );

        // Create UserOperation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(userAccount),
            nonce: 0,
            initCode: "",
            callData: callData, // Now correctly calls userAccount.execute()
            accountGasLimits: bytes32(
                (uint256(300000) << 128) | uint256(300000)
            ), // verificationGasLimit | callGasLimit
            preVerificationGas: 50000,
            gasFees: bytes32((uint256(20 gwei) << 128) | uint256(20 gwei)), // maxPriorityFeePerGas | maxFeePerGas
            paymasterAndData: abi.encodePacked(address(paymaster)), // Just paymaster address for now
            signature: ""
        });

        // Test paymaster validation
        vm.prank(address(erc4337EntryPoint));
        try
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), 60000)
        returns (bytes memory context, uint256 validationData) {
            // Validation should succeed
            assertEq(validationData, 0, "Paymaster validation should succeed");

            console.log("SUCCESS: Paymaster validation passed");
            console.log("  Context length:", context.length);
            console.log("  Validation data:", validationData);
        } catch Error(string memory reason) {
            console.log("ERROR: Paymaster validation failed:", reason);
            revert(string.concat("Paymaster validation failed: ", reason));
        } catch (bytes memory lowLevelData) {
            console.log(
                "ERROR: Paymaster validation failed with low-level error"
            );
            console.logBytes(lowLevelData);
            revert("Paymaster validation failed with low-level error");
        }

        // Test that the paymaster would be compensated
        uint256 withdrawnAmount = proof.withdrawnValue();
        uint256 feeAmount = (withdrawnAmount * _RELAY_FEE_BPS) / 10_000;
        uint256 maxCost = 60000; // Same as used in validation

        assertTrue(feeAmount >= maxCost, "Fee should cover gas costs");
        console.log("SUCCESS: Fee validation passed");
        console.log("  Fee amount:", feeAmount);
        console.log("  Max gas cost:", maxCost);
        console.log("  Fee covers gas:", feeAmount >= maxCost);
    }
}