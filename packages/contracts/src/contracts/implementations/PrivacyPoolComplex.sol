// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrivacyPool} from '../PrivacyPool.sol';
import {IERC20, SafeERC20} from '@oz/token/ERC20/utils/SafeERC20.sol';

contract PrivacyPoolComplex is PrivacyPool {
  using SafeERC20 for IERC20;

  error NativeAssetNotAccepted();

  constructor(address _entrypoint, address _verifier, address _asset) PrivacyPool(_entrypoint, _verifier, _asset) {}

  function _handleValueInput(address _sender, uint256 _amount) internal override(PrivacyPool) {
    if (msg.value != 0) revert NativeAssetNotAccepted();
    IERC20(ASSET).safeTransferFrom(_sender, address(this), _amount);
  }

  function _handleValueOutput(address _recipient, uint256 _amount) internal override(PrivacyPool) {
    IERC20(ASSET).safeTransferFrom(address(this), _recipient, _amount);
  }
}
