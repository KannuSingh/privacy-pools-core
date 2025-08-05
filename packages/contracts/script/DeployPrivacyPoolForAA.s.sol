// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {PrivacyPoolSimple} from "src/contracts/implementations/PrivacyPoolSimple.sol";
import {SimplePrivacyPoolPaymaster} from "src/contracts/SimplePrivacyPoolPaymaster.sol";
import {IEntryPoint as IERC4337EntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IEntrypoint} from "src/interfaces/IEntrypoint.sol";
import {IPrivacyPool} from "src/interfaces/IPrivacyPool.sol";

contract DeployPrivacyPoolForAA is Script {
    // Already deployed addresses
    address constant WITHDRAWAL_VERIFIER =
        0x53Eba1e079F885482238EE8bf01C4A9f09DE458f;
    address constant ENTRYPOINT = 0x56186c1e64ca8043DEF78d06Aff222212ea5df71;
    address constant POSEIDON_T3 = 0x056e4a859558a3975761abD7385506BC4D8a8E60;
    address constant POSEIDON_T4 = 0x259435d8Df5171c5Cc48B6aF3F8578420be4bc99;

    // ERC-4337 EntryPoint (Base Sepolia)
    address constant ERC4337_ENTRYPOINT =
        0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function run() external {
        vm.startBroadcast();

        console.log("Deploying Privacy Pool contracts...");
        console.log("Using Entrypoint:", ENTRYPOINT);
        console.log("Using Withdrawal Verifier:", WITHDRAWAL_VERIFIER);

        // Deploy SimplePrivacyPool
        PrivacyPoolSimple ethPrivacyPool = new PrivacyPoolSimple(
            ENTRYPOINT,
            WITHDRAWAL_VERIFIER,
            WITHDRAWAL_VERIFIER // Using same verifier for ragequit
        );

        console.log("SimplePrivacyPool deployed to:", address(ethPrivacyPool));

        // Deploy SimplePrivacyPoolPaymaster
        SimplePrivacyPoolPaymaster paymaster = new SimplePrivacyPoolPaymaster(
            IERC4337EntryPoint(ERC4337_ENTRYPOINT),
            IEntrypoint(ENTRYPOINT),
            IPrivacyPool(address(ethPrivacyPool))
        );

        console.log("SimplePrivacyPoolPaymaster deployed to:", address(paymaster));

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("SimplePrivacyPool:", address(ethPrivacyPool));
        console.log("SimplePrivacyPoolPaymaster:", address(paymaster));
    }
}
