// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';
import {Constants} from 'contracts/lib/Constants.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {Script} from 'forge-std/Script.sol';
import {Multicaller} from 'multicaller/Multicaller.sol';

contract MassDeposit is Script {
  /// @notice Mainnet Entrypoint
  Entrypoint public constant ENTRYPOINT = Entrypoint(payable(0x6818809EefCe719E480a7526D76bD3e561526b46));
  /// @notice Mainnet Multicaller
  Multicaller public constant MULTICALLER = Multicaller(payable(0x0000000000002Bdbf1Bf3279983603Ec279CC6dF));

  uint256 internal constant _DEPOSIT_AMOUNT = 820;
  uint256 internal constant _BATCH_SIZE = 82;
  uint256 internal constant _BATCH_AMOUNT = 10;

  error WrongChainId();
  error WrongAmountOfDeposits();
  error WrongAmountOfPrecommitmentsUsed();

  address public owner = 0xAd7f9A19E2598b6eFE0A25C84FB1c87F81eB7159;

  function setUp() public view {
    if (block.chainid != 1) revert WrongChainId();
  }

  function run() public {
    // Set minimum deposit amount to zero
    vm.prank(owner);
    ENTRYPOINT.updatePoolConfiguration(IERC20(Constants.NATIVE_ASSET), 0, 0, 0);

    // Get the precommitments
    string[] memory _inputs = new string[](2);
    _inputs[0] = 'node';
    _inputs[1] = 'script/utils/precommitments.mjs';
    bytes memory _result = vm.ffi(_inputs);

    uint256[] memory _precommitments = abi.decode(_result, (uint256[]));
    uint256 _amount = _precommitments.length;

    // Check we're properly parsing all precommitments
    if (_amount != _DEPOSIT_AMOUNT) revert WrongAmountOfDeposits();

    // Track the processed precommitments
    uint256 _k;

    // Populate the arrays for the multicaller
    address[] memory _targets = new address[](_BATCH_SIZE);
    bytes[] memory _datas = new bytes[](_BATCH_SIZE);
    uint256[] memory _values = new uint256[](_BATCH_SIZE);

    vm.startBroadcast();

    (,, address _caller) = vm.readCallers();

    // Make 10 multicalls
    for (uint256 _i; _i < _BATCH_AMOUNT; ++_i) {
      // Make 82 deposits
      for (uint256 _j; _j < _BATCH_SIZE; ++_j) {
        _targets[_j] = address(ENTRYPOINT);
        _datas[_j] = abi.encodeWithSignature('deposit(uint256)', _precommitments[_k]);
        // `_values` is kept zeroe'd
        ++_k;
      }

      MULTICALLER.aggregate(_targets, _datas, _values, _caller);
    }

    if (_k != _DEPOSIT_AMOUNT) revert WrongAmountOfPrecommitmentsUsed();

    vm.stopBroadcast();
  }
}
