// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/*

Made with ♥ for 0xBow by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks/

*/

import {ProofLib} from './lib/ProofLib.sol';

import {AccessControlUpgradeable} from '@oz-upgradeable/access/AccessControlUpgradeable.sol';
import {UUPSUpgradeable} from '@oz-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {SafeERC20} from '@oz/token/ERC20/utils/SafeERC20.sol';

import {ReentrancyGuardUpgradeable} from '@oz-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @title Entrypoint
 * @notice Serves as the main entrypoint for a series of ASP-operated Privacy Pools
 */
contract Entrypoint is AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, IEntrypoint {
  using SafeERC20 for IERC20;
  using ProofLib for ProofLib.WithdrawProof;

  // `keccak256('OWNER_ROLE')`
  bytes32 public constant OWNER_ROLE = 0x6270edb7c868f86fda4adedba75108201087268ea345934db8bad688e1feb91b;
  // `keccak256('ASP_POSTMAN')`
  bytes32 public constant ASP_POSTMAN = 0xfc84ade01695dae2ade01aa4226dc40bdceaf9d5dbd3bf8630b1dd5af195bbc5;
  // Constant address for the native asset
  address private immutable ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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

  function initialize(address _owner, address _postman) external initializer {
    // Sanity check initial addresses
    if (_owner == address(0)) revert ZeroAddress();
    if (_postman == address(0)) revert ZeroAddress();

    // Initialize upgradeable contractcs
    __ReentrancyGuard_init();
    __AccessControl_init();

    // Initialize roles
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_ROLE);
    _grantRole(OWNER_ROLE, _owner);
    _grantRole(ASP_POSTMAN, _postman);
  }

  /*///////////////////////////////////////////////////////////////
                            RECEIVE
  //////////////////////////////////////////////////////////////*/

  receive() external payable {}

  /*///////////////////////////////////////////////////////////////
                      ASSOCIATION SET METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function updateRoot(uint256 _root, bytes32 _ipfsHash) external onlyRole(ASP_POSTMAN) returns (uint256 _index) {
    // Check provided values are non-zero
    if (_root == 0) revert EmptyRoot();
    if (_ipfsHash == 0) revert EmptyIPFSHash();

    // Push new association set
    associationSets.push(AssociationSetData(_root, _ipfsHash, block.timestamp));
    _index = associationSets.length;

    emit RootUpdated(_root, _ipfsHash, block.timestamp);
  }

  /*///////////////////////////////////////////////////////////////
                          DEPOSIT METHODS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function deposit(uint256 _precommitment) external payable returns (uint256 _commitment) {
    _commitment = _handleDeposit(IERC20(ETH), msg.value, _precommitment);
  }

  /// @inheritdoc IEntrypoint
  function deposit(IERC20 _asset, uint256 _value, uint256 _precommitment) external returns (uint256 _commitment) {
    // Pull funds from user
    _asset.safeTransferFrom(msg.sender, address(this), _value);
    _commitment = _handleDeposit(_asset, _value, _precommitment);
  }

  /*///////////////////////////////////////////////////////////////
                               RELAY
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function relay(
    IPrivacyPool.Withdrawal calldata _withdrawal,
    ProofLib.WithdrawProof calldata _proof
  ) external nonReentrant {
    // Check withdrawal amount is non-zero
    if (_proof.withdrawnValue() == 0) revert InvalidWithdrawalAmount();
    // Check allowed processooor is this Entrypoint
    if (_withdrawal.processooor != address(this)) revert InvalidProcessooor();

    // Fetch pool by scope
    IPrivacyPool _pool = scopeToPool[_withdrawal.scope];
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Store pool asset
    IERC20 _asset = IERC20(_pool.ASSET());
    uint256 _balanceBefore = _assetBalance(_asset);

    // Process withdrawal
    _pool.withdraw(_withdrawal, _proof);

    // Decode fee data
    FeeData memory _data = abi.decode(_withdrawal.data, (FeeData));
    uint256 _withdrawnAmount = _proof.withdrawnValue();

    // Deduct fees
    uint256 _amountAfterFees = _deductFee(_withdrawnAmount, _data.relayFeeBPS);

    // Transfer withdrawn funds to recipient
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
  ) external onlyRole(OWNER_ROLE) {
    // Sanity check values
    if (address(_asset) == address(0)) revert ZeroAddress();
    if (address(_pool) == address(0)) revert ZeroAddress();
    if (_vettingFeeBPS > 10_000) revert InvalidFeeBPS();

    // Fetch pool configuration
    AssetConfig storage _config = assetConfig[_asset];
    if (address(_config.pool) != address(0)) revert AssetPoolAlreadyRegistered();

    // Fetch pool scope
    uint256 _scope = _pool.SCOPE();
    if (address(scopeToPool[_scope]) != address(0)) revert ScopePoolAlreadyRegistered();

    // Store pool configuration
    scopeToPool[_scope] = _pool;
    _config.pool = _pool;
    _config.minimumDepositAmount = _minimumDepositAmount;
    _config.vettingFeeBPS = _vettingFeeBPS;

    // If asset is an ERC20, approve pool to spend
    if (address(_asset) != ETH) _asset.approve(address(_pool), type(uint256).max);

    emit PoolRegistered(_pool, _asset, _scope);
  }

  /// @inheritdoc IEntrypoint
  function removePool(IERC20 _asset) external onlyRole(OWNER_ROLE) {
    // Fetch pool by asset
    IPrivacyPool _pool = assetConfig[_asset].pool;
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Fetch pool scope
    uint256 _scope = _pool.SCOPE();

    // If asset is an ERC20, revoke pool allowance
    if (address(_asset) != ETH) _asset.approve(address(_pool), 0);

    // Remove pool configuration
    delete scopeToPool[_scope];
    delete assetConfig[_asset];

    emit PoolRemoved(_pool, _asset, _scope);
  }

  /// @inheritdoc IEntrypoint
  function updatePoolConfiguration(
    IERC20 _asset,
    uint256 _minimumDepositAmount,
    uint256 _vettingFeeBPS
  ) external onlyRole(OWNER_ROLE) {
    // Check fee is less than 100%
    if (_vettingFeeBPS > 10_000) revert InvalidFeeBPS();

    // Fetch pool configuration
    AssetConfig storage _config = assetConfig[_asset];
    if (address(_config.pool) == address(0)) revert PoolNotFound();

    // Update asset configuration
    _config.minimumDepositAmount = _minimumDepositAmount;
    _config.vettingFeeBPS = _vettingFeeBPS;

    emit PoolConfigurationUpdated(_config.pool, _asset, _minimumDepositAmount, _vettingFeeBPS);
  }

  /// @inheritdoc IEntrypoint
  function windDownPool(IPrivacyPool _pool) external onlyRole(OWNER_ROLE) {
    // Call `windDown` on pool
    _pool.windDown();

    emit PoolWindDown(_pool);
  }

  /// @inheritdoc IEntrypoint
  function withdrawFees(IERC20 _asset, address _recipient) external nonReentrant onlyRole(OWNER_ROLE) {
    // Fetch current asset balance
    uint256 _balance = _assetBalance(_asset);

    // Transfer funds
    _transfer(_asset, _recipient, _balance);

    emit FeesWithdrawn(_asset, _recipient, _balance);
  }

  /*///////////////////////////////////////////////////////////////
                           VIEW METHODS 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEntrypoint
  function latestRoot() external view returns (uint256 _root) {
    if (associationSets.length == 0) revert NoRootsAvailable();
    _root = associationSets[associationSets.length - 1].root;
  }

  /// @inheritdoc IEntrypoint
  function rootByIndex(uint256 _index) external view returns (uint256 _root) {
    if (_index >= associationSets.length) revert InvalidIndex();
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
   * @notice Handle deposit logic for both ETH and ERC20 deposits
   * @param _asset The asset being deposited
   * @param _value The amount being deposited
   * @param _precommitment The precommitment for the deposit
   * @return _commitment The deposit commitment hash
   */
  function _handleDeposit(IERC20 _asset, uint256 _value, uint256 _precommitment) internal returns (uint256 _commitment) {
    // Fetch pool by asset
    AssetConfig memory _config = assetConfig[_asset];
    IPrivacyPool _pool = _config.pool;
    if (address(_pool) == address(0)) revert PoolNotFound();

    // Check minimum deposit amount
    if (_value < _config.minimumDepositAmount) revert MinimumDepositAmount();

    // Deduct vetting fees
    uint256 _amountAfterFees = _deductFee(_value, _config.vettingFeeBPS);

    // Deposit commitment into pool (forwarding native asset if applicable)
    uint256 _nativeAssetValue = address(_asset) == ETH ? _amountAfterFees : 0;
    _commitment = _pool.deposit{value: _nativeAssetValue}(msg.sender, _amountAfterFees, _precommitment);

    emit Deposited(msg.sender, _pool, _commitment, _amountAfterFees);
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
   * @notice Deduct fees from an amount
   * @param _amount The amount before fees
   * @param _feeBPS The fee in basis points
   */
  function _deductFee(uint256 _amount, uint256 _feeBPS) internal pure returns (uint256 _afterFees) {
    unchecked {
      // Fee calculation cannot overflow as _feeBPS is validated to be <= 10000
      _afterFees = _amount - (_amount * _feeBPS / 10_000);
    }
  }
}
