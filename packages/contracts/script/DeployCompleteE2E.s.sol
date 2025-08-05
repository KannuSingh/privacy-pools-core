// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// Privacy Pool contracts
import {Entrypoint} from "src/contracts/Entrypoint.sol";
import {PrivacyPoolSimple} from "src/contracts/implementations/PrivacyPoolSimple.sol";
import {SimplePrivacyPoolPaymaster} from "src/contracts/SimplePrivacyPoolPaymaster.sol";
import {CommitmentVerifier} from "src/contracts/verifiers/CommitmentVerifier.sol";
import {WithdrawalVerifier} from "src/contracts/verifiers/WithdrawalVerifier.sol";

// OpenZeppelin contracts
import {ERC1967Proxy} from "@oz/proxy/ERC1967/ERC1967Proxy.sol";

// Interfaces
import {IEntryPoint as IERC4337EntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IEntrypoint} from "src/interfaces/IEntrypoint.sol";
import {IPrivacyPool} from "src/interfaces/IPrivacyPool.sol";
import {IERC20} from "@oz/interfaces/IERC20.sol";

import {Constants} from "src/contracts/lib/Constants.sol";

contract DeployCompleteE2E is Script {
    // ERC-4337 EntryPoint (Base Sepolia)
    address constant ERC4337_ENTRYPOINT =
        0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    // Pool parameters
    uint256 constant MIN_DEPOSIT = 0.1 ether;
    uint256 constant VETTING_FEE_BPS = 100; // 1%
    uint256 constant MAX_RELAY_FEE_BPS = 1000; // 10%

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== COMPLETE E2E DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Deployer will be both OWNER and POSTMAN for simplicity");
        console.log("");

        // 1. Deploy verifiers
        console.log("1. Deploying Verifiers...");
        WithdrawalVerifier withdrawalVerifier = new WithdrawalVerifier();
        CommitmentVerifier commitmentVerifier = new CommitmentVerifier();

        // 2. Deploy Privacy Pool Entrypoint with proxy
        console.log("2. Deploying Privacy Pool Entrypoint...");
        Entrypoint entrypointImpl = new Entrypoint();

        bytes memory entrypointInitData = abi.encodeCall(
            Entrypoint.initialize,
            (deployer, deployer) // deployer as both owner and postman
        );

        ERC1967Proxy entrypointProxy = new ERC1967Proxy(
            address(entrypointImpl),
            entrypointInitData
        );

        Entrypoint entrypoint = Entrypoint(payable(address(entrypointProxy)));

        // 3. Deploy Privacy Pool
        console.log("3. Deploying Privacy Pool...");
        PrivacyPoolSimple privacyPool = new PrivacyPoolSimple(
            address(entrypoint),
            address(withdrawalVerifier),
            address(commitmentVerifier)
        );

        // 4. Register Privacy Pool with Entrypoint
        console.log("4. Registering Privacy Pool...");
        entrypoint.registerPool(
            IERC20(Constants.NATIVE_ASSET), // ETH
            IPrivacyPool(address(privacyPool)),
            MIN_DEPOSIT,
            VETTING_FEE_BPS,
            MAX_RELAY_FEE_BPS
        );
        console.log("   Privacy Pool registered successfully");

        // 5. Deploy Paymaster
        console.log("5. Deploying Privacy Pool Paymaster...");
        SimplePrivacyPoolPaymaster paymaster = new SimplePrivacyPoolPaymaster(
            IERC4337EntryPoint(ERC4337_ENTRYPOINT),
            IEntrypoint(address(entrypoint)),
            IPrivacyPool(address(privacyPool))
        );

        console.log("   SimplePrivacyPoolPaymaster:", address(paymaster));

        // 6. Fund paymaster for gas sponsorship
        console.log("6. Funding Paymaster...");
        uint256 paymasterFunding = 10 ether;
        paymaster.deposit{value: paymasterFunding}();

        console.log("   Paymaster funded with", paymasterFunding / 1e18, "ETH");

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Addresses for E2E script:");
        console.log("ENTRYPOINT:", address(entrypoint));
        console.log("PRIVACY_POOL:", address(privacyPool));
        console.log("PAYMASTER:", address(paymaster));
        console.log("WITHDRAWAL_VERIFIER:", address(withdrawalVerifier));
        console.log("COMMITMENT_VERIFIER:", address(commitmentVerifier));
    }
}
