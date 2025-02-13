// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';

import {Script} from 'forge-std/Script.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

import {Constants} from 'contracts/lib/Constants.sol';

/**
 * @notice Script to register a Privacy Pool.
 */
contract RegisterPool is Script {
  // @notice The deployed Entrypoint
  Entrypoint public entrypoint;
  // @notice The Pool asset
  IERC20 internal _asset;
  // @notice The PrivacyPool address
  IPrivacyPool internal _pool;
  // @notice The minimum amount to deposit
  uint256 internal _minimumDepositAmount;
  // @notice The vetting fee in basis points
  uint256 internal _vettingFeeBPS;

  function setUp() public {
    // Read the Entrypoint address from environment
    entrypoint = Entrypoint(payable(vm.envAddress('ENTRYPOINT_ADDRESS')));

    // Ask the user for the asset address
    try vm.parseAddress(vm.prompt('Enter asset address (empty for native)')) returns (address _assetAddress) {
      _asset = IERC20(_assetAddress);
    } catch {
      _asset = IERC20(Constants.NATIVE_ASSET);
    }

    // Ask the user for the PrivayPool address
    _pool = IPrivacyPool(vm.parseAddress(vm.prompt('Enter pool address')));
    // Ask the user for the minimum deposit amount
    _minimumDepositAmount = vm.parseUint(vm.prompt('Enter minimum deposit amount padded with decimals'));
    // Ask the user for the vetting fee in basis points
    _vettingFeeBPS = vm.parseUint(vm.prompt('Enter vetting fee BPS'));
  }

  // @dev Must be called with the `--account` flag which acts as the caller
  function run() public {
    vm.startBroadcast();

    // Register pool
    entrypoint.registerPool(_asset, _pool, _minimumDepositAmount, _vettingFeeBPS);

    vm.stopBroadcast();
  }
}

contract UpdateRoot is Script {
  // @notice The deployed Entrypoint
  Entrypoint public entrypoint;

  bytes32 public IPFS_HASH = keccak256('ipfs_hash');
  uint256 public newRoot;

  function setUp() public {
    // Read the Entrypoint address from environment
    entrypoint = Entrypoint(payable(vm.envAddress('ENTRYPOINT_ADDRESS')));

    // Build merkle tree and compute root
    newRoot = computeMerkleRoot();
  }

  function computeMerkleRoot() internal returns (uint256) {
    string[] memory runCommand = new string[](2);
    runCommand[0] = 'node';
    runCommand[1] = 'script/utils/tree.mjs';
    bytes memory result = vm.ffi(runCommand);

    // Parse the root from the output
    return abi.decode(result, (uint256));
  }

  // @dev Must be called with the `--account` flag which acts as the caller
  function run() public {
    vm.startBroadcast();

    // Register pool
    entrypoint.updateRoot(newRoot, IPFS_HASH);

    vm.stopBroadcast();
  }
}
