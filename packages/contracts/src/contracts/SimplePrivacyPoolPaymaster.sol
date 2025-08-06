// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

// import {console} from "forge-std/console.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {BasePaymaster} from "@account-abstraction/contracts/core/BasePaymaster.sol";
import {_packValidationData} from "@account-abstraction/contracts/core/Helpers.sol";
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";

import {IPrivacyPool} from "interfaces/IPrivacyPool.sol";
import {IEntrypoint} from "interfaces/IEntrypoint.sol";
import {IState} from "interfaces/IState.sol";
import {ProofLib} from "contracts/lib/ProofLib.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IERC20} from "@oz/interfaces/IERC20.sol";
import {Constants} from "./lib/Constants.sol";

/**
 * @title SimplePrivacyPoolPaymaster
 * @notice ERC-4337 Paymaster for Privacy Pool withdrawals
 * @dev This paymaster performs comprehensive validation to ensure it only sponsors successful withdrawals
 */
contract SimplePrivacyPoolPaymaster is BasePaymaster {
    using ProofLib for ProofLib.WithdrawProof;
    using UserOperationLib for PackedUserOperation;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Privacy Pool Entrypoint contract
    IEntrypoint public immutable PRIVACY_POOL_ENTRYPOINT;

    /// @notice ETH Privacy Pool contract
    IPrivacyPool public immutable ETH_PRIVACY_POOL;

    /// @notice Withdrawal proof verifier
    IVerifier public immutable WITHDRAWAL_VERIFIER;

    /// @notice Estimated gas cost for postOp operations
    uint256 public constant POST_OP_GAS_LIMIT = 25000;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PrivacyPoolWithdrawalSponsored(
        address indexed userAccount,
        bytes32 indexed userOpHash,
        uint256 actualWithdrawalCost,
        uint256 refunded
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCallData();
    error InvalidProof();
    error InsufficientFee(uint256 required, uint256 provided);
    error InvalidWithdrawal();
    error InvalidProcessooor();
    error InvalidScope();
    error InvalidWithdrawalAmount();
    error RelayFeeGreaterThanMax();
    error NullifierAlreadySpent();
    error InvalidStateRoot();
    error InvalidTreeDepth();
    error InsufficientPostOpGasLimit();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy Simple Privacy Pool Paymaster
     * @param _entryPoint ERC-4337 EntryPoint contract
     * @param _privacyEntrypoint Privacy Pool Entrypoint contract
     * @param _ethPrivacyPool ETH Privacy Pool contract
     */
    constructor(
        IEntryPoint _entryPoint,
        IEntrypoint _privacyEntrypoint,
        IPrivacyPool _ethPrivacyPool
    ) BasePaymaster(_entryPoint) {
        PRIVACY_POOL_ENTRYPOINT = _privacyEntrypoint;
        ETH_PRIVACY_POOL = _ethPrivacyPool;
        WITHDRAWAL_VERIFIER = IVerifier(_ethPrivacyPool.WITHDRAWAL_VERIFIER());
    }

    /*//////////////////////////////////////////////////////////////
                          PAYMASTER VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validate a UserOperation for Privacy Pool withdrawal
     * @dev Performs the same validation as Privacy Pool to ensure success
     * @param userOp The UserOperation to validate
     * @param userOpHash Hash of the UserOperation
     * @param maxCost Maximum gas cost the paymaster might pay
     * @return context Encoded context with user info and expected costs for postOp
     * @return validationData 0 if valid, packed failure data otherwise
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        // 1. Decode UserOp callData
        (
            address target,
            uint256 value,
            bytes memory data
        ) = _decodeExecuteCallData(userOp.callData);

        // 2. Validate target is Privacy Pool Entrypoint
        if (target != address(PRIVACY_POOL_ENTRYPOINT)) {
            return ("", _packValidationData(true, 0, 0));
        }

        // 3. Validate no direct ETH transfer
        if (value != 0) {
            return ("", _packValidationData(true, 0, 0));
        }

        // 4. Check post-op gas limit is sufficient
        uint256 postOpGasLimit = userOp.unpackPostOpGasLimit();
        if (postOpGasLimit < POST_OP_GAS_LIMIT) {
            revert InsufficientPostOpGasLimit();
        }

        // 5. Decode relay call data
        (
            IPrivacyPool.Withdrawal memory withdrawal,
            ProofLib.WithdrawProof memory proof,
            uint256 scope
        ) = _decodeRelayCallData(data);

        // 6. Perform full Entrypoint.relay() validation
        if (!_validateRelayCall(withdrawal, proof, scope)) {
            return ("", _packValidationData(true, 0, 0));
        }

        // 7. Perform full PrivacyPool.withdraw() validation
        if (!_validateWithdrawCall(withdrawal, proof)) {
            return ("", _packValidationData(true, 0, 0));
        }

        // 8. Validate paymaster will be paid adequately
        IEntrypoint.RelayData memory relayData = abi.decode(
            withdrawal.data,
            (IEntrypoint.RelayData)
        );
        uint256 withdrawnAmount = proof.withdrawnValue();
        uint256 expectedFeeAmount = (withdrawnAmount * relayData.relayFeeBPS) /
            10_000;

        if (expectedFeeAmount < maxCost) {
            return ("", _packValidationData(true, 0, 0));
        }

        if (relayData.feeRecipient != address(this)) {
            return ("", _packValidationData(true, 0, 0));
        }

        // All validations passed - encode context for postOp
        // Context contains: userOpHash, sender address, expected cost, withdrawn amount
        context = abi.encode(
            userOpHash,
            userOp.sender,
            expectedFeeAmount // Expected feeAmount to be paid to paymaster after calldata execution
        );

        return (context, 0);
    }

    /*//////////////////////////////////////////////////////////////
                      ENTRYPOINT RELAY VALIDATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validate withdrawal parameters (mirrors Entrypoint.relay logic)
     */
    function _validateRelayCall(
        IPrivacyPool.Withdrawal memory withdrawal,
        ProofLib.WithdrawProof memory proof,
        uint256 scope
    ) internal view returns (bool) {
        // Check withdrawn amount is non-zero
        if (proof.withdrawnValue() == 0) {
            return false;
        }

        // Check allowed processooor is Privacy Entrypoint
        if (withdrawal.processooor != address(PRIVACY_POOL_ENTRYPOINT)) {
            return false;
        }

        // Fetch pool by scope and validate
        IPrivacyPool pool = PRIVACY_POOL_ENTRYPOINT.scopeToPool(scope);
        if (address(pool) != address(ETH_PRIVACY_POOL)) {
            return false;
        }

        // Decode and validate relay data
        IEntrypoint.RelayData memory relayData = abi.decode(
            withdrawal.data,
            (IEntrypoint.RelayData)
        );

        // Get asset config from entrypoint
        IERC20 asset = IERC20(pool.ASSET());
        (
            IPrivacyPool _pool,
            uint256 _minimumDepositAmount,
            uint256 _vettingFeeBPS,
            uint256 _maxRelayFeeBPS
        ) = PRIVACY_POOL_ENTRYPOINT.assetConfig(asset);

        if (relayData.relayFeeBPS > _maxRelayFeeBPS) {
            return false;
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                     PRIVACY POOL WITHDRAW VALIDATION  
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validate withdrawal proof (mirrors PrivacyPool.withdraw logic)
     */
    function _validateWithdrawCall(
        IPrivacyPool.Withdrawal memory withdrawal,
        ProofLib.WithdrawProof memory proof
    ) internal view returns (bool) {
        // 1. Validate withdrawal context matches proof
        uint256 expectedContext = uint256(
            keccak256(abi.encode(withdrawal, ETH_PRIVACY_POOL.SCOPE()))
        ) % (Constants.SNARK_SCALAR_FIELD);

        if (proof.context() != expectedContext) {
            return false;
        }
        // 2. Check the tree depth signals are less than the max tree depth
        if (
            proof.stateTreeDepth() > ETH_PRIVACY_POOL.MAX_TREE_DEPTH() ||
            proof.ASPTreeDepth() > ETH_PRIVACY_POOL.MAX_TREE_DEPTH()
        ) {
            return false;
        }

        // 3. Check state root is valid (same as _isKnownRoot in State.sol)
        uint256 stateRoot = proof.stateRoot();
        if (!_isKnownRoot(stateRoot)) {
            return false;
        }

        // 4. Validate ASP root is latest (same as PrivacyPool validation)
        uint256 aspRoot = proof.ASPRoot();
        if (aspRoot != PRIVACY_POOL_ENTRYPOINT.latestRoot()) {
            return false;
        }

        // 5. Check nullifier hasn't been spent
        uint256 nullifierHash = proof.existingNullifierHash();
        if (ETH_PRIVACY_POOL.nullifierHashes(nullifierHash)) {
            return false;
        }

        // 6. Verify Groth16 proof with withdrawal verifier
        if (
            !WITHDRAWAL_VERIFIER.verifyProof(
                proof.pA,
                proof.pB,
                proof.pC,
                proof.pubSignals
            )
        ) {
            return false;
        }

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a root is known/valid (mirrors State._isKnownRoot)
     * @param _root The root to validate
     * @return True if the root is in the last ROOT_HISTORY_SIZE roots
     */
    function _isKnownRoot(uint256 _root) internal view returns (bool) {
        if (_root == 0) return false;

        // Start from the most recent root (current index)
        uint32 _index = ETH_PRIVACY_POOL.currentRootIndex();
        uint32 ROOT_HISTORY_SIZE = ETH_PRIVACY_POOL.ROOT_HISTORY_SIZE();

        // Check all possible roots in the history
        for (uint32 _i = 0; _i < ROOT_HISTORY_SIZE; _i++) {
            if (_root == ETH_PRIVACY_POOL.roots(_index)) return true;
            _index = (_index + ROOT_HISTORY_SIZE - 1) % ROOT_HISTORY_SIZE;
        }

        return false;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLDATA DECODING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Decode SimpleAccount.execute() callData
     */
    function _decodeExecuteCallData(
        bytes calldata callData
    ) internal pure returns (address target, uint256 value, bytes memory data) {
        // SimpleAccount.execute() selector: 0xb61d27f6
        if (callData.length < 4 || bytes4(callData[:4]) != 0xb61d27f6) {
            revert InvalidCallData();
        }

        (target, value, data) = abi.decode(
            callData[4:],
            (address, uint256, bytes)
        );
    }

    /**
     * @notice Decode Privacy Pool Entrypoint.relay() callData
     */
    function _decodeRelayCallData(
        bytes memory data
    )
        internal
        pure
        returns (
            IPrivacyPool.Withdrawal memory withdrawal,
            ProofLib.WithdrawProof memory proof,
            uint256 scope
        )
    {
        if (data.length < 4) {
            revert InvalidCallData();
        }

        // Create a new bytes array for the parameters (skip 4-byte selector)
        bytes memory params = new bytes(data.length - 4);
        for (uint256 i = 0; i < data.length - 4; i++) {
            params[i] = data[i + 4];
        }

        (withdrawal, proof, scope) = abi.decode(
            params,
            (IPrivacyPool.Withdrawal, ProofLib.WithdrawProof, uint256)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow contract to receive ETH from Privacy Pool fees and refunds
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            POST-OP OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handle post-operation gas cost calculation and refunds
     * @dev Called after UserOperation execution to calculate actual costs and refund excess
     * @param mode Post-operation mode (success/failure)
     * @param context Encoded context from validation containing user info and expected costs
     * @param actualGasCost Actual gas cost of the UserOperation
     * @param actualUserOpFeePerGas Gas price paid by the UserOperation
     */
    function _postOp(
        IPaymaster.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) internal override {
        // Decode context from validation phase
        (bytes32 userOpHash, address sender, uint256 expectedFeeAmount) = abi
            .decode(context, (bytes32, address, uint256));

        // Calculate total actual cost including postOp overhead
        uint256 postOpCost = POST_OP_GAS_LIMIT * actualUserOpFeePerGas;
        uint256 actualWithdrawalCost = actualGasCost + postOpCost;
        uint256 refundAmount = expectedFeeAmount > actualWithdrawalCost
            ? expectedFeeAmount - actualWithdrawalCost
            : 0;
        // If actual cost is less than expected, refund the difference to the user
        if (refundAmount > 0) {
            // Transfer refund to user's smart account
            (bool success, ) = sender.call{value: refundAmount}("");
            // If refund fails, we keep the excess (this shouldn't happen with smart accounts)
        }

        // Emit withdrawal tracking event (regardless of mode)
        emit PrivacyPoolWithdrawalSponsored(
            sender,
            userOpHash,
            actualWithdrawalCost, // this is what user paid for withdrawal
            refundAmount
        );
    }
}
