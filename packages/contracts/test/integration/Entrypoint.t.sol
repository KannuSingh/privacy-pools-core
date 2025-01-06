// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

contract IntegrationEntrypoint is IntegrationBase {
  function test_skip() public {
    vm.skip(true);
  }
}
