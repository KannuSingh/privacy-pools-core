// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrivacyPool} from '../PrivacyPool.sol';

contract PrivacyPoolSimple is PrivacyPool {
  error InsufficientValue();
  error FailedToSendETH();

  constructor(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidon
  ) PrivacyPool(_entrypoint, _verifier, _asset, _poseidon) {}

  function _handleValueInput(address, uint256 _amount) internal override(PrivacyPool) {
    if (msg.value != _amount) revert InsufficientValue();
  }

  function _handleValueOutput(address _recipient, uint256 _amount) internal override(PrivacyPool) {
    (bool _success,) = _recipient.call{value: _amount}('');
    if (!_success) revert FailedToSendETH();
  }
}
