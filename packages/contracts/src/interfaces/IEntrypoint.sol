// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

interface IEntrypoint {
  struct AssetConfig {
    IPrivacyPool pool;
    uint256 minimumDepositAmount;
    uint256 feeBPS;
  }

  struct FeeData {
    address recipient;
    address feeRecipient;
    uint256 feeBPS;
  }

  struct AssociationSetData {
    uint256 root;
    bytes32 ipfsHash;
    uint256 timestamp;
  }

  error PoolNotFound();
  error AssetPoolAlreadyRegistered();
  error ScopePoolAlreadyRegistered();
  error MinimumDepositAmount();
  error InvalidProcessooor();
  error InvalidPoolState();
  error EmptyIPFSHash();
  error EmptyRoot();

  event PoolWindDown(IPrivacyPool _pool);
  event PoolRegistered(IPrivacyPool _pool, IERC20 _asset, uint256 _scope);
  event PoolRemoved(IPrivacyPool _pool, IERC20 _asset, uint256 _scope);
  event RootUpdated(uint256 _root, bytes32 _ipfsHash, uint256 _timestamp);
  event Deposited(address indexed _depositor, IPrivacyPool indexed _pool, uint256 _amount);
  event WithdrawalRelayed(
    address indexed _relayer, address indexed _recipient, IERC20 indexed _asset, uint256 _amount, uint256 _feeAmount
  );

  function latestRoot() external returns (uint256);

  function deposit(uint256 _precommitment) external payable returns (uint256 _commitment);

  function deposit(IERC20 _asset, uint256 _value, uint256 _precommitment) external returns (uint256 _commitment);
}
