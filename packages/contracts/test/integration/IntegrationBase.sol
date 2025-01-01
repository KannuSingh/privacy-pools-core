// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Entrypoint, IEntrypoint} from "contracts/Entrypoint.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract IntegrationBase is Test {
    uint256 internal constant _FORK_BLOCK = 18_920_905;

    IEntrypoint internal _entrypoint;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), _FORK_BLOCK);
        vm.prank(_owner);
        _entrypoint = new Entrypoint();
    }
}
