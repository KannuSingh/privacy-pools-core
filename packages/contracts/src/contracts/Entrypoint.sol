// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from './lib/ProofLib.sol';

import {AccessControl} from '@oz/access/AccessControl.sol';
import {Initializable} from '@oz/proxy/utils/Initializable.sol';
import {UUPSUpgradeable} from '@oz/proxy/utils/UUPSUpgradeable.sol';
import {SafeERC20} from '@oz/token/ERC20/utils/SafeERC20.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @title Entrypoint
 * @notice Serves as the main entrypoint for a series of ASP-operated Privacy Pools
 */
contract Entrypoint is AccessControl, UUPSUpgradeable, Initializable, IEntrypoint {
  using SafeERC20 for IERC20;
  using ProofLib for ProofLib.Proof;

  bytes32 public constant OWNER_ROLE = 0x6270edb7c868f86fda4adedba75108201087268ea345934db8bad688e1feb91b;
  bytes32 public constant ADMIN_ROLE = 0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42;
  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @inheritdoc IEntrypoint
  mapping(uint256 _scope => IPrivacyPool _pool) public scopeToPool;

  /// @inheritdoc IEntrypoint
  mapping(IERC20 _asset => AssetConfig _config) public assetConfig;

  /// @inheritdoc IEntrypoint
  AssociationSetData[] public associationSets;

  /*///////////////////////////////////////////////////////////////
                          INITIALIZATION
  //////////////////////////////////////////////////////////////*/

  constructor() {
    _disableInitializers();
  }

  receive() external payable {}

  function initialize(address _owner, address _admin) external initializer {
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_ROLE);
    _grantRole(OWNER_ROLE, _owner);
    _grantRole(ADMIN_ROLE, _admin);
  }

  /*///////////////////////////////////////////////////////////////
                      ASSOCIATION SET METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function updateRoot(uint256 _root, bytes32 _ipfsHash) external onlyRole(ADMIN_ROLE) returns (uint256 _index) {
    if (_root == 0) revert EmptyRoot();
    if (_ipfsHash == 0) revert EmptyIPFSHash();

    associationSets.push(AssociationSetData(_root, _ipfsHash, block.timestamp));
    _index = associationSets.length;

    emit RootUpdated(_root, _ipfsHash, block.timestamp);
  }

  /*///////////////////////////////////////////////////////////////
                          DEPOSIT METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function deposit(uint256 _precommitment) external payable returns (uint256 _commitment) {
    AssetConfig memory _config = assetConfig[IERC20(ETH)];

    // Fetch ETH pool
    IPrivacyPool _pool = _config.pool;
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Check deposited value is bigger than minimum
    if (msg.value < _config.minimumDepositAmount) {
      revert MinimumDepositAmount();
    }

    // Deduct vetting fees
    uint256 _amountAfterFees = _deductFee(msg.value, _config.vettingFeeBPS);

    // Deposit commitment into pool
    _commitment = _pool.deposit{value: _amountAfterFees}(msg.sender, _amountAfterFees, _precommitment);

    emit Deposited(msg.sender, _pool, _commitment, _amountAfterFees);
  }

  /// @inheritdoc IEntrypoint
  function deposit(IERC20 _asset, uint256 _value, uint256 _precommitment) external returns (uint256 _commitment) {
    AssetConfig memory _config = assetConfig[_asset];

    // Fetch pool by asset
    IPrivacyPool _pool = _config.pool;
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Check deposited value is bigger than minimum
    if (_value < _config.minimumDepositAmount) {
      revert MinimumDepositAmount();
    }

    // Deduct vetting fees
    uint256 _amountAfterFees = _deductFee(_value, _config.vettingFeeBPS);

    // Transfer assets from user to Entrypoint using `SafeERC20`
    _asset.safeTransferFrom(msg.sender, address(this), _value);

    // Deposit commitment into pool
    _commitment = _pool.deposit(msg.sender, _amountAfterFees, _precommitment);

    emit Deposited(msg.sender, _pool, _commitment, _amountAfterFees);
  }

  /*///////////////////////////////////////////////////////////////
                               RELAY
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function relay(IPrivacyPool.Withdrawal calldata _withdrawal, ProofLib.Proof calldata _proof) external {
    // Fetch pool by proof scope
    IPrivacyPool _pool = scopeToPool[_proof.scope()];
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Store pool asset
    IERC20 _asset = IERC20(_pool.ASSET());

    uint256 _balanceBefore = _assetBalance(_asset);

    // Check allowed processooor is this Entrypoint
    if (_withdrawal.processooor != address(this)) {
      revert InvalidProcessooor();
    }

    // Process withdrawal
    _pool.withdraw(_withdrawal, _proof);

    // Decode fee data
    FeeData memory _data = abi.decode(_withdrawal.data, (FeeData));
    uint256 _withdrawnAmount = _proof.withdrawnAmount();

    // Deduct fees
    uint256 _amountAfterFees = _deductFee(_withdrawnAmount, _data.relayFeeBPS);

    _transfer(_asset, _data.recipient, _amountAfterFees);

    // Transfer fees to fee recipient
    _transfer(_asset, _data.feeRecipient, _withdrawnAmount - _amountAfterFees);

    // Check pool balance has not been reduced
    uint256 _balanceAfter = _assetBalance(_asset);
    if (_balanceBefore > _balanceAfter) revert InvalidPoolState();

    emit WithdrawalRelayed(msg.sender, _data.recipient, _asset, _withdrawnAmount, _withdrawnAmount - _amountAfterFees);
  }

  /*///////////////////////////////////////////////////////////////
                          POOL MANAGEMENT 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function registerPool(
    IERC20 _asset,
    IPrivacyPool _pool,
    uint256 _minimumDepositAmount,
    uint256 _vettingFeeBPS
  ) external onlyRole(ADMIN_ROLE) {
    AssetConfig storage _config = assetConfig[_asset];

    if (address(_config.pool) != address(0)) {
      revert AssetPoolAlreadyRegistered();
    }

    uint256 _scope = _pool.SCOPE();
    if (address(scopeToPool[_scope]) != address(0)) {
      revert ScopePoolAlreadyRegistered();
    }

    scopeToPool[_scope] = _pool;

    _config.pool = _pool;
    _config.minimumDepositAmount = _minimumDepositAmount;
    _config.vettingFeeBPS = _vettingFeeBPS;

    _asset.approve(address(_pool), type(uint256).max);

    emit PoolRegistered(_pool, _asset, _scope);
  }

  /// @inheritdoc IEntrypoint
  function removePool(IERC20 _asset) external onlyRole(ADMIN_ROLE) {
    IPrivacyPool _pool = assetConfig[_asset].pool;
    if (address(_pool) == address(0)) revert PoolNotFound();

    uint256 _scope = _pool.SCOPE();

    _asset.approve(address(_pool), 0);

    delete scopeToPool[_scope];
    delete assetConfig[_asset];

    emit PoolRemoved(_pool, _asset, _scope);
  }

  /// @inheritdoc IEntrypoint
  function windDownPool(IPrivacyPool _pool) external onlyRole(OWNER_ROLE) {
    _pool.windDown();
    emit PoolWindDown(_pool);
  }

  /// @inheritdoc IEntrypoint
  function withdrawFees(IERC20 _asset, address _recipient) external onlyRole(ADMIN_ROLE) {
    uint256 _balance;
    if (_asset == IERC20(ETH)) {
      _balance = address(this).balance;
      (bool _success,) = _recipient.call{value: _balance}('');
      if (!_success) revert ETHTransferFailed();
    } else {
      _balance = _asset.balanceOf(address(this));
      _asset.safeTransfer(_recipient, _balance);
    }

    emit FeesWithdrawn(_asset, _recipient, _balance);
  }

  /*///////////////////////////////////////////////////////////////
                           VIEW METHODS 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function latestRoot() external view returns (uint256 _root) {
    _root = associationSets[associationSets.length].root;
  }

  /// @inheritdoc IEntrypoint
  function rootByIndex(uint256 _index) external view returns (uint256 _root) {
    _root = associationSets[_index].root;
  }

  /*///////////////////////////////////////////////////////////////
                        INTERNAL METHODS 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Authorize an upgrade
   * @dev Inherited from `UUPSUpgradeable`
   */
  function _authorizeUpgrade(address) internal override onlyRole(OWNER_ROLE) {}

  /**
   * @notice Deduct fees from an amount
   * @param _amount The amount before fees
   * @param _feeBPS The fee in basis points
   */
  function _deductFee(uint256 _amount, uint256 _feeBPS) internal pure returns (uint256 _afterFees) {
    _afterFees = _amount - (_amount * _feeBPS) / 10_000;
  }

  /**
   * @notice Fetch asset balance for the Entrypoint
   * @param _asset The asset address
   * @return _balance The asset balance
   */
  function _assetBalance(IERC20 _asset) internal view returns (uint256 _balance) {
    if (_asset == IERC20(ETH)) {
      _balance = address(this).balance;
    } else {
      _balance = _asset.balanceOf(address(this));
    }
  }

  /**
   * @notice Transfer out an asset to a recipient
   * @param _asset The asset to send
   * @param _recipient The recipient address
   * @param _amount The amount to send
   */
  function _transfer(IERC20 _asset, address _recipient, uint256 _amount) internal {
    if (_asset == IERC20(ETH)) {
      (bool _success,) = _recipient.call{value: _amount}('');
      if (!_success) revert ETHTransferFailed();
    } else {
      _asset.safeTransfer(_recipient, _amount);
    }
  }
}

