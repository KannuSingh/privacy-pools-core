// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';

import {Script} from 'forge-std/Script.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

contract RegisterPool is Script {
  Entrypoint public entrypoint;

  IERC20 internal _asset;
  IPrivacyPool internal _pool;
  uint256 internal _minimumDepositAmount;
  uint256 internal _vettingFeeBPS;

  address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function setUp() public {
    entrypoint = Entrypoint(payable(vm.envAddress('ENTRYPOINT_ADDRESS')));

    try vm.parseAddress(vm.prompt('Enter asset address')) returns (address _assetAddress) {
      _asset = IERC20(_assetAddress);
    } catch {
      _asset = IERC20(_ETH);
    }

    _pool = IPrivacyPool(vm.parseAddress(vm.prompt('Enter pool address')));
    _minimumDepositAmount = vm.parseUint(vm.prompt('Enter minimum deposit amount'));
    _vettingFeeBPS = vm.parseUint(vm.prompt('Enter vetting fee BPS'));
  }

  function run() public {
    vm.startBroadcast();

    entrypoint.registerPool(_asset, _pool, _minimumDepositAmount, _vettingFeeBPS);

    vm.stopBroadcast();
  }
}
