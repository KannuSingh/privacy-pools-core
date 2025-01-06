// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrivacyPool} from '../PrivacyPool.sol';
import {IPrivacyPoolSimple} from 'interfaces/IPrivacyPool.sol';

/**
 * @title PrivacyPoolSimple
 * @notice Native asset implementation of Privacy Pool.
 */
contract PrivacyPoolSimple is PrivacyPool, IPrivacyPoolSimple {
  constructor(
    address _entrypoint,
    address _verifier,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  )
    PrivacyPool(_entrypoint, _verifier, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, _poseidonT2, _poseidonT3, _poseidonT4)
  {}

  /**
   * @notice Handle receiving native asset asset
   * @param _amount The amount of asset receiving
   */
  function _pull(address, uint256 _amount) internal override(PrivacyPool) {
    if (msg.value != _amount) revert InsufficientValue();
  }

  /**
   * @notice Handle sending native asset
   * @param _recipient The address of the user receiving the asset
   * @param _amount The amount of native asset being sent
   */
  function _push(address _recipient, uint256 _amount) internal override(PrivacyPool) {
    (bool _success,) = _recipient.call{value: _amount}('');
    if (!_success) revert FailedToSendETH();
  }
}
