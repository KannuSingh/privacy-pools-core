// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrivacyPool} from '../PrivacyPool.sol';

import {IERC20, SafeERC20} from '@oz/token/ERC20/utils/SafeERC20.sol';
import {IPrivacyPoolComplex} from 'interfaces/IPrivacyPool.sol';

/**
 * @title PrivacyPoolComplex
 * @notice ERC20 implementation of Privacy Pool.
 */
contract PrivacyPoolComplex is PrivacyPool, IPrivacyPoolComplex {
  using SafeERC20 for IERC20;

  constructor(address _entrypoint, address _verifier, address _asset) PrivacyPool(_entrypoint, _verifier, _asset) {}

  /**
   * @notice Handle pulling an ERC20 asset
   * @param _sender The address of the user transferring the asset from
   * @param _amount The amount of asset being pulled
   */
  function _pull(address _sender, uint256 _amount) internal override(PrivacyPool) {
    // This contract does not accept native asset
    if (msg.value != 0) revert NativeAssetNotAccepted();

    // Pull asset from sender to this contract
    IERC20(ASSET).safeTransferFrom(_sender, address(this), _amount);
  }

  /**
   * @notice Handle sending an ERC20 asset
   * @param _recipient The address of the user receiving the asset
   * @param _amount The amount of asset being sent
   */
  function _push(address _recipient, uint256 _amount) internal override(PrivacyPool) {
    // Send asset from this contract to recipient
    IERC20(ASSET).safeTransfer(_recipient, _amount);
  }
}
