// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Entrypoint, IEntrypoint} from 'contracts/Entrypoint.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

contract UnitEntrypoint is Test {
  function test_skip() public {
    vm.skip(true);
  }
}
