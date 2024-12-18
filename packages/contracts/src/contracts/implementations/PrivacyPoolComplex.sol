// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PrivacyPool} from "../PrivacyPool.sol";
import {IERC20, SafeERC20} from "@oz/token/ERC20/utils/SafeERC20.sol";

contract PrivacyPoolSimple is PrivacyPool {
    using SafeERC20 for IERC20;

    constructor(
        address _entrypoint,
        address _verifier,
        address _asset,
        address _poseidon
    ) PrivacyPool(_entrypoint, _verifier, _asset, _poseidon) {}

    function _handleValueInput(
        address _sender,
        uint256 _amount
    ) internal override(PrivacyPool) {
        ASSET.safeTransferFrom(_sender, address(this), _amount);
    }

    function _handleValueOutput(
        address _recipient,
        uint256 _amount
    ) internal override(PrivacyPool) {
        ASSET.safeTransferFrom(address(this), _recipient, _amount);
    }
}
