// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAccessControl} from '@oz/access/IAccessControl.sol';

import {Initializable} from '@oz/proxy/utils/Initializable.sol';
import {ERC20, IERC20} from '@oz/token/ERC20/ERC20.sol';
import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {IPrivacyPool} from 'contracts/PrivacyPool.sol';
import {ProofLib} from 'contracts/lib/ProofLib.sol';

import {Entrypoint, IEntrypoint} from 'contracts/Entrypoint.sol';
import {Test} from 'forge-std/Test.sol';

struct PoolParams {
  address pool;
  address asset;
  uint256 minDeposit;
  uint256 vettingFeeBPS;
}

struct RelayParams {
  address caller;
  address processooor;
  address recipient;
  address feeRecipient;
  uint256 feeBPS;
  uint256 scope;
  address asset;
  uint256 amount;
  address pool;
}

contract PrivacyPoolERC20ForTest {
  address internal _asset;

  function withdraw(IPrivacyPool.Withdrawal calldata, ProofLib.Proof calldata _proof) external {
    uint256 _amount = _proof.pubSignals[0];
    IERC20(_asset).transfer(msg.sender, _amount);
  }

  function setAsset(address __asset) external {
    _asset = __asset;
  }
}

contract PrivacyPoolETHForTest {
  function withdraw(IPrivacyPool.Withdrawal calldata, ProofLib.Proof calldata _proof) external {
    uint256 _amount = _proof.pubSignals[0];
    msg.sender.call{value: _amount}('');
  }
}

contract FaultyPrivacyPool is Test {
  function withdraw(IPrivacyPool.Withdrawal calldata, ProofLib.Proof calldata) external {
    // remove half of the eth balance from msg.sender
    deal(msg.sender, msg.sender.balance / 2);
  }
}

contract ERC20forTest is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}

/**
 * @notice Mock contract for testing
 */
contract EntrypointForTest is Entrypoint {
  function mockPool(PoolParams memory _params) external {
    IEntrypoint.AssetConfig storage _config = assetConfig[IERC20(_params.asset)];
    _config.pool = IPrivacyPool(_params.pool);
    _config.minimumDepositAmount = _params.minDeposit;
    _config.vettingFeeBPS = _params.vettingFeeBPS;
  }

  function mockScopeToPool(uint256 _scope, address _pool) external {
    scopeToPool[_scope] = IPrivacyPool(_pool);
  }

  function mockAssociationSets(uint256 _root, bytes32 _ipfsHash) external {
    associationSets.push(IEntrypoint.AssociationSetData({root: _root, ipfsHash: _ipfsHash, timestamp: block.timestamp}));
  }
}

/**
 * @notice Base test contract for Entrypoint
 */
contract UnitEntrypoint is Test {
  EntrypointForTest internal _entrypoint;

  address internal immutable _OWNER = makeAddr('owner');
  address internal immutable _POSTMAN = makeAddr('postman');
  address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /*///////////////////////////////////////////////////////////////
                           MODIFIERS 
  //////////////////////////////////////////////////////////////*/

  modifier givenCallerHasPostmanRole() {
    vm.startPrank(_POSTMAN);
    _;
    vm.stopPrank();
  }

  modifier givenCallerHasOwnerRole() {
    vm.startPrank(_OWNER);
    _;
    vm.stopPrank();
  }

  modifier givenPoolExists(PoolParams memory _params) {
    _validAddress(_params.pool);
    _validAddress(_params.asset);
    _params.vettingFeeBPS = bound(_params.vettingFeeBPS, 0, 10_000);
    _params.minDeposit = bound(_params.minDeposit, 1, 100);
    _entrypoint.mockPool(_params);
    _;
  }

  /*///////////////////////////////////////////////////////////////
                           SETUP 
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    address _impl = address(new EntrypointForTest());

    _entrypoint = EntrypointForTest(
      payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(Entrypoint.initialize, (_OWNER, _POSTMAN))))
    );
  }

  /*///////////////////////////////////////////////////////////////
                           HELPERS 
  //////////////////////////////////////////////////////////////*/

  function _mockAndExpect(address _contract, bytes memory _call, bytes memory _return) internal {
    vm.mockCall(_contract, _call, _return);
    vm.expectCall(_contract, _call);
  }

  function _mockAndExpect(address _contract, uint256 _value, bytes memory _call, bytes memory _return) internal {
    vm.mockCall(_contract, _value, _call, _return);
    vm.expectCall(_contract, _value, _call);
  }

  function _deductFee(uint256 _amount, uint256 _feeBPS) internal pure returns (uint256 _afterFees) {
    _afterFees = _amount - (_amount * _feeBPS) / 10_000;
  }

  function _validAddress(address _address) internal {
    // Avoid vm, console, and create2deployer, entrypoint proxy, implementation addresses, and precompile addresses
    vm.assume(
      _address != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)
        && _address != address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        && _address != address(0x000000000000000000636F6e736F6c652e6c6f67)
        && _address != address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f) && _address != address(_entrypoint)
        && _address != address(this) && _address > address(10)
    );
  }
}

/**
 * @notice Unit tests for Entrypoint constructor and initializer
 */
contract UnitConstructor is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint is initialized
   */
  function test_ConstructorWhenDeployed() external {
    bytes32 _initializableStorageSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    bytes32 _data = vm.load(address(_entrypoint), _initializableStorageSlot);
    uint64 _initialized = uint64(uint256(_data)); // First 64 bits contain _initialized
    assertEq(_initialized, 1);
  }

  /**
   * @notice Test that the Entrypoint is initialized with valid owner and admin
   */
  function test_InitializeGivenValidOwnerAndAdmin() external {
    assertEq(_entrypoint.hasRole(_entrypoint.OWNER_ROLE(), _OWNER), true);
    assertEq(_entrypoint.hasRole(_entrypoint.ASP_POSTMAN(), _POSTMAN), true);
  }

  /**
   * @notice Test that the Entrypoint reverts when already initialized
   */
  function test_InitializeWhenAlreadyInitialized() external {
    vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
    _entrypoint.initialize(_OWNER, _POSTMAN);
  }
}

/**
 * @notice Unit tests for Entrypoint root update functionality
 */
contract UnitRootUpdate is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint updates the root and emits an event
   */
  function test_UpdateRootGivenValidRootAndIpfsHash(
    uint256 _root,
    bytes32 _ipfsHash,
    uint256 _timestamp
  ) external givenCallerHasPostmanRole {
    vm.assume(_root != 0);
    vm.assume(_ipfsHash != 0);

    vm.warp(_timestamp);

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.RootUpdated(_root, _ipfsHash, _timestamp);

    uint256 _index = _entrypoint.updateRoot(_root, _ipfsHash);
    (uint256 _retrievedRoot, bytes32 _retrievedIpfsHash, uint256 _retrievedTimestamp) = _entrypoint.associationSets(0);
    assertEq(_retrievedRoot, _root);
    assertEq(_retrievedIpfsHash, _ipfsHash);
    assertEq(_retrievedTimestamp, _timestamp);
    assertEq(_index, 1);
  }

  function test_UpdateRootWhenRootIsZero(bytes32 _ipfsHash) external givenCallerHasPostmanRole {
    vm.assume(_ipfsHash != 0);

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.EmptyRoot.selector));
    _entrypoint.updateRoot(0, _ipfsHash);
  }

  /**
   * @notice Test that the Entrypoint reverts when the IPFS hash is zero
   */
  function test_UpdateRootWhenIpfsHashIsZero(uint256 _root) external givenCallerHasPostmanRole {
    vm.assume(_root != 0);
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.EmptyIPFSHash.selector));
    _entrypoint.updateRoot(_root, 0);
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the postman role
   */
  function test_UpdateRootWhenCallerLacksPostmanRole(address _caller, uint256 _root, bytes32 _ipfsHash) external {
    vm.assume(_caller != _POSTMAN);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.ASP_POSTMAN()
      )
    );
    vm.prank(_caller);
    _entrypoint.updateRoot(_root, _ipfsHash);
  }
}

/**
 * @notice Unit tests for Entrypoint deposit functionality
 */
contract UnitDeposit is UnitEntrypoint {
  function test_DepositETHGivenValueMeetsMinimum(
    address _depositor,
    uint256 _amount,
    uint256 _precommitment,
    uint256 _commitment,
    // solhint-disable-next-line no-unused-vars
    PoolParams memory _params
  )
    external
    givenPoolExists(
      PoolParams({pool: _params.pool, asset: _ETH, minDeposit: _params.minDeposit, vettingFeeBPS: _params.vettingFeeBPS})
    )
  {
    _validAddress(_depositor);

    (IPrivacyPool _pool, uint256 _minDeposit, uint256 _vettingFeeBPS) = _entrypoint.assetConfig(IERC20(_ETH));
    // Can't be too big, otherwise overflows
    _amount = bound(_amount, _minDeposit, 1e30);
    uint256 _amountAfterFees = _deductFee(_amount, _vettingFeeBPS);
    deal(_depositor, _amount);

    _mockAndExpect(
      address(_pool),
      _amountAfterFees,
      abi.encodeWithSignature('deposit(address,uint256,uint256)', _depositor, _amountAfterFees, _precommitment),
      abi.encode(_commitment)
    );

    uint256 _depositorBalanceBefore = _depositor.balance;

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.Deposited(_depositor, _pool, _commitment, _amountAfterFees);

    vm.prank(_depositor);
    _entrypoint.deposit{value: _amount}(_precommitment);

    assertEq(_depositor.balance, _depositorBalanceBefore - _amount);
    // eth sent to pool was mocked, so balance won't change
    assertEq(address(_entrypoint).balance, _amount);
  }

  /**
   * @notice Test that the Entrypoint reverts when the deposit amount is below the minimum deposit amount
   */
  function test_DepositETHWhenValueBelowMinimum(
    address _depositor,
    uint256 _amount,
    uint256 _precommitment,
    // solhint-disable-next-line no-unused-vars
    PoolParams memory _params
  )
    external
    givenPoolExists(
      PoolParams({pool: _params.pool, asset: _ETH, minDeposit: _params.minDeposit, vettingFeeBPS: _params.vettingFeeBPS})
    )
  {
    vm.assume(_depositor != address(0));

    (, uint256 _minDeposit, uint256 _vettingFeeBPS) = _entrypoint.assetConfig(IERC20(_ETH));
    _amount = bound(_amount, 0, _minDeposit - 1);
    vm.deal(_depositor, _amount);

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.MinimumDepositAmount.selector));
    vm.prank(_depositor);
    _entrypoint.deposit{value: _amount}(_precommitment);
  }

  function test_DepositETHWhenPoolNotFound(address _depositor, uint256 _amount, uint256 _precommitment) external {
    vm.deal(_depositor, _amount);
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    vm.prank(_depositor);
    _entrypoint.deposit{value: _amount}(_precommitment);
  }

  /**
   * @notice Test that the Entrypoint deposits ERC20 tokens and emits an event
   */
  function test_DepositERC20GivenValueMeetsMinimum(
    address _depositor,
    uint256 _amount,
    uint256 _precommitment,
    uint256 _commitment,
    PoolParams memory _params
  ) external givenPoolExists(_params) {
    vm.assume(_depositor != address(0));

    // Can't be too big, otherwise overflows
    _amount = bound(_amount, _params.minDeposit, 1e30);
    uint256 _amountAfterFees = _deductFee(_amount, _params.vettingFeeBPS);

    _mockAndExpect(
      _params.asset,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _depositor, address(_entrypoint), _amount),
      abi.encode(true)
    );

    _mockAndExpect(
      _params.pool,
      abi.encodeWithSignature('deposit(address,uint256,uint256)', _depositor, _amountAfterFees, _precommitment),
      abi.encode(_commitment)
    );

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.Deposited(_depositor, IPrivacyPool(_params.pool), _commitment, _amountAfterFees);

    vm.prank(_depositor);
    _entrypoint.deposit(IERC20(_params.asset), _amount, _precommitment);
  }

  function test_DepositERC20WhenValueBelowMinimum(
    address _depositor,
    uint256 _amount,
    uint256 _precommitment,
    PoolParams memory _params
  ) external givenPoolExists(_params) {
    vm.assume(_depositor != address(0));

    (, uint256 _minDeposit, uint256 _vettingFeeBPS) = _entrypoint.assetConfig(IERC20(_params.asset));
    _amount = bound(_amount, 0, _minDeposit - 1);

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.MinimumDepositAmount.selector));
    vm.prank(_depositor);
    _entrypoint.deposit(IERC20(_params.asset), _amount, _precommitment);
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_DepositERC20WhenPoolNotFound(
    address _depositor,
    address _asset,
    uint256 _amount,
    uint256 _precommitment
  ) external {
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    vm.prank(_depositor);
    _entrypoint.deposit(IERC20(_asset), _amount, _precommitment);
  }
}

/**
 * @notice Unit tests for Entrypoint relay functionality
 */
contract UnitRelay is UnitEntrypoint {
  using ProofLib for ProofLib.Proof;

  /**
   * @notice Test that the Entrypoint relays a valid withdrawal and proof (for ERC20)
   */
  function test_RelayERC20GivenValidWithdrawalAndProof(
    RelayParams memory _params,
    ProofLib.Proof memory _proof
  ) external {
    vm.assume(_params.asset != _ETH);

    _params.asset = address(new ERC20forTest('Test', 'TEST'));
    _params.pool = address(new PrivacyPoolERC20ForTest());
    _validAddress(_params.recipient);
    _validAddress(_params.feeRecipient);
    vm.assume(_params.recipient != _params.feeRecipient);
    vm.assume(_params.recipient != address(_entrypoint));
    vm.assume(_params.feeRecipient != address(_entrypoint));
    vm.assume(_params.amount != 0);
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    uint256 _amountAfterFees = _deductFee(_params.amount, _params.feeBPS);
    uint256 _feeAmount = _params.amount - _amountAfterFees;
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));
    deal(_params.asset, _params.pool, _params.amount);
    PrivacyPoolERC20ForTest(_params.pool).setAsset(_params.asset);

    uint256 _poolBalanceBefore = IERC20(_params.asset).balanceOf(_params.pool);
    uint256 _entrypointBalanceBefore = IERC20(_params.asset).balanceOf(address(_entrypoint));
    uint256 _recipientBalanceBefore = IERC20(_params.asset).balanceOf(_params.recipient);
    uint256 _feeRecipientBalanceBefore = IERC20(_params.asset).balanceOf(_params.feeRecipient);

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(
      _params.caller, _params.recipient, IERC20(_params.asset), _params.amount, _feeAmount
    );

    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);

    assertEq(IERC20(_params.asset).balanceOf(_params.pool), _poolBalanceBefore - _params.amount);
    assertEq(IERC20(_params.asset).balanceOf(address(_entrypoint)), _entrypointBalanceBefore);
    assertEq(IERC20(_params.asset).balanceOf(_params.recipient), _recipientBalanceBefore + _amountAfterFees);
    assertEq(IERC20(_params.asset).balanceOf(_params.feeRecipient), _feeRecipientBalanceBefore + _feeAmount);
  }

  /**
   * @notice Test that the Entrypoint relays a valid withdrawal and proof (for ETH)
   */
  function test_RelayETHGivenValidWithdrawalAndProof(RelayParams memory _params, ProofLib.Proof memory _proof) external {
    _validAddress(_params.recipient);
    _validAddress(_params.feeRecipient);
    vm.assume(_params.recipient != _params.feeRecipient);
    vm.assume(_params.recipient != address(_entrypoint));
    vm.assume(_params.feeRecipient != address(_entrypoint));
    vm.assume(_params.amount != 0);
    _params.asset = _ETH;
    _params.pool = address(new PrivacyPoolETHForTest());

    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    uint256 _amountAfterFees = _deductFee(_params.amount, _params.feeBPS);
    uint256 _feeAmount = _params.amount - _amountAfterFees;
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));
    deal(_params.pool, _params.amount);

    uint256 _poolBalanceBefore = address(_params.pool).balance;
    uint256 _entrypointBalanceBefore = address(_entrypoint).balance;
    uint256 _recipientBalanceBefore = address(_params.recipient).balance;
    uint256 _feeRecipientBalanceBefore = address(_params.feeRecipient).balance;

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(
      _params.caller, _params.recipient, IERC20(_params.asset), _params.amount, _feeAmount
    );

    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);

    assertEq(address(_params.pool).balance, _poolBalanceBefore - _params.amount);
    assertEq(address(_entrypoint).balance, _entrypointBalanceBefore);
    assertEq(address(_params.recipient).balance, _recipientBalanceBefore + _amountAfterFees);
    assertEq(address(_params.feeRecipient).balance, _feeRecipientBalanceBefore + _feeAmount);
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool state is invalid
   */
  function test_RelayInvalidPoolState(RelayParams memory _params, ProofLib.Proof memory _proof) external {
    _validAddress(_params.recipient);
    _validAddress(_params.feeRecipient);
    vm.assume(_params.amount != 0);
    _params.asset = _ETH;
    _params.pool = address(new FaultyPrivacyPool());

    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    // give pool more than the amount to withdraw
    deal(address(_entrypoint), _params.amount * 2);
    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.InvalidPoolState.selector));
    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);
  }

  /**
   * @notice Test that the Entrypoint reverts when the withdrawal amount is zero
   */
  function test_RelayWhenWithdrawalAmountIsZero(
    IPrivacyPool.Withdrawal memory _withdrawal,
    ProofLib.Proof memory _proof
  ) external {
    // set withdrawn value to 0
    _proof.pubSignals[0] = 0;
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.InvalidWithdrawalAmount.selector));
    vm.prank(_withdrawal.processooor);
    _entrypoint.relay(_withdrawal, _proof);
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_RelayWhenPoolNotFound(
    address _caller,
    IPrivacyPool.Withdrawal memory _withdrawal,
    ProofLib.Proof memory _proof
  ) external {
    vm.assume(_proof.pubSignals[0] != 0);
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    vm.prank(_caller);
    _entrypoint.relay(_withdrawal, _proof);
  }

  /**
   * @notice Test that the Entrypoint reverts when the processooor is not valid
   */
  function test_RelayWhenInvalidProcessooor(
    address _processooor,
    RelayParams memory _params,
    ProofLib.Proof memory _proof
  ) external {
    _validAddress(_params.asset);
    _validAddress(_params.pool);
    vm.assume(_processooor != address(_entrypoint));
    vm.assume(_params.amount != 0);
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: _processooor, scope: _params.scope, data: _data});

    _entrypoint.mockScopeToPool(_params.scope, _params.pool);

    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));
    if (_params.asset != _ETH) {
      _mockAndExpect(
        _params.asset,
        abi.encodeWithSelector(IERC20.balanceOf.selector, address(_entrypoint)),
        abi.encode(_params.amount)
      );
    }

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.InvalidProcessooor.selector));
    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);
  }
}

/**
 * @notice Unit tests for Entrypoint pool registration functionality
 */
contract UnitRegisterPool is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint registers a new pool
   */
  function test_RegisterPoolGivenPoolNotRegistered(
    address _pool,
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external givenCallerHasOwnerRole {
    _validAddress(_pool);
    _validAddress(_asset);
    vm.assume(_vettingFeeBPS <= 10_000);

    uint256 _scope = uint256(keccak256(abi.encodePacked(_pool, block.chainid, _asset)));
    _mockAndExpect(_pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    if (_asset != _ETH) {
      _mockAndExpect(
        _asset, abi.encodeWithSelector(IERC20.approve.selector, _pool, type(uint256).max), abi.encode(true)
      );
    }

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolRegistered(IPrivacyPool(_pool), IERC20(_asset), _scope);

    _entrypoint.registerPool(IERC20(_asset), IPrivacyPool(_pool), _minDeposit, _vettingFeeBPS);

    (IPrivacyPool _retrievedPool, uint256 _retrievedMinDeposit, uint256 _retrievedFeeBPS) =
      _entrypoint.assetConfig(IERC20(_asset));
    assertEq(address(_retrievedPool), _pool);
    assertEq(_retrievedMinDeposit, _minDeposit);
    assertEq(_retrievedFeeBPS, _vettingFeeBPS);
  }

  /**
   * @notice Test that the Entrypoint reverts when the asset pool is already registered
   */
  function test_RegisterPoolWhenAssetPoolExists(PoolParams memory _params)
    external
    givenCallerHasOwnerRole
    givenPoolExists(_params)
  {
    vm.assume(_params.pool != address(0));
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.AssetPoolAlreadyRegistered.selector));
    _entrypoint.registerPool(
      IERC20(_params.asset), IPrivacyPool(_params.pool), _params.minDeposit, _params.vettingFeeBPS
    );
  }

  /**
   * @notice Test that the Entrypoint reverts when the scope pool is already registered
   */
  function test_RegisterPoolWhenScopePoolExists(
    address _pool,
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external givenCallerHasOwnerRole {
    _validAddress(_pool);
    _validAddress(_asset);
    vm.assume(_vettingFeeBPS <= 10_000);

    uint256 _scope = uint256(keccak256(abi.encodePacked(_pool, block.chainid, _asset)));
    _entrypoint.mockScopeToPool(_scope, _pool);
    _mockAndExpect(_pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.ScopePoolAlreadyRegistered.selector));
    _entrypoint.registerPool(IERC20(_asset), IPrivacyPool(_pool), _minDeposit, _vettingFeeBPS);
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_RegisterPoolWhenCallerLacksOwnerRole(
    address _caller,
    address _pool,
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external {
    vm.assume(_caller != _OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.OWNER_ROLE()
      )
    );
    vm.prank(_caller);
    _entrypoint.registerPool(IERC20(_asset), IPrivacyPool(_pool), _minDeposit, _vettingFeeBPS);
  }
}

/**
 * @notice Unit tests for Entrypoint pool removal functionality
 */
contract UnitRemovePool is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint removes a pool
   */
  function test_RemovePoolGivenPoolExists(
    PoolParams memory _params,
    uint256 _scope
  ) external givenCallerHasOwnerRole givenPoolExists(_params) {
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    if (_params.asset != _ETH) {
      _mockAndExpect(_params.asset, abi.encodeWithSelector(IERC20.approve.selector, _params.pool, 0), abi.encode(true));
    }

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolRemoved(IPrivacyPool(_params.pool), IERC20(_params.asset), _scope);

    _entrypoint.removePool(IERC20(_params.asset));

    (IPrivacyPool _retrievedPool, uint256 _retrievedMinDeposit, uint256 _retrievedFeeBPS) =
      _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(address(_retrievedPool), address(0));
    assertEq(_retrievedMinDeposit, 0);
    assertEq(_retrievedFeeBPS, 0);
    assertEq(address(_entrypoint.scopeToPool(_scope)), address(0));
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_RemovePoolWhenPoolNotFound(address _asset) external givenCallerHasOwnerRole {
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    _entrypoint.removePool(IERC20(_asset));
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_RemovePoolWhenCallerLacksOwnerRole(address _caller, address _asset) external {
    vm.assume(_caller != _OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.OWNER_ROLE()
      )
    );
    vm.prank(_caller);
    _entrypoint.removePool(IERC20(_asset));
  }
}

/**
 * @notice Unit tests for Entrypoint pool configuration update functionality
 */
contract UnitUpdatePoolConfiguration is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint updates the pool configuration
   */
  function test_UpdatePoolConfigurationGivenPoolExists(
    PoolParams memory _params,
    PoolParams memory _newParams
  ) external givenCallerHasOwnerRole givenPoolExists(_params) {
    (IPrivacyPool _pool, uint256 _minDeposit, uint256 _vettingFeeBPS) = _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(address(_pool), _params.pool);
    assertEq(_minDeposit, _params.minDeposit);
    assertEq(_vettingFeeBPS, _params.vettingFeeBPS);

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolConfigurationUpdated(
      IPrivacyPool(_params.pool), IERC20(_params.asset), _newParams.minDeposit, _newParams.vettingFeeBPS
    );

    _entrypoint.updatePoolConfiguration(IERC20(_params.asset), _newParams.minDeposit, _newParams.vettingFeeBPS);
    (, uint256 _newMinDeposit, uint256 _newVettingFeeBPS) = _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(_newMinDeposit, _newParams.minDeposit);
    assertEq(_newVettingFeeBPS, _newParams.vettingFeeBPS);
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_UpdatePoolConfigurationWhenPoolNotFound(
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external givenCallerHasOwnerRole {
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    _entrypoint.updatePoolConfiguration(IERC20(_asset), _minDeposit, _vettingFeeBPS);
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_UpdatePoolConfigurationWhenCallerLacksOwnerRole(
    address _caller,
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external {
    vm.assume(_caller != _OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.OWNER_ROLE()
      )
    );
    vm.prank(_caller);
    _entrypoint.updatePoolConfiguration(IERC20(_asset), _minDeposit, _vettingFeeBPS);
  }
}

/**
 * @notice Unit tests for Entrypoint pool wind down functionality
 */
contract UnitWindDownPool is UnitEntrypoint {
  function test_WindDownPoolGivenPoolExists(PoolParams memory _params)
    external
    givenCallerHasOwnerRole
    givenPoolExists(_params)
  {
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.windDown.selector), abi.encode(true));

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolWindDown(IPrivacyPool(_params.pool));

    _entrypoint.windDownPool(IPrivacyPool(_params.pool));
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_WindDownPoolWhenCallerLacksOwnerRole(
    address _caller,
    PoolParams memory _params
  ) external givenPoolExists(_params) {
    vm.assume(_caller != _OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.OWNER_ROLE()
      )
    );
    vm.prank(_caller);
    _entrypoint.windDownPool(IPrivacyPool(_params.pool));
  }
}

/**
 * @notice Unit tests for Entrypoint fees withdrawal functionality
 */
contract UnitWithdrawFees is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint withdraws fees for ETH
   */
  function test_WithdrawFeesWhenETHBalanceExists(uint256 _balance, address _recipient) external givenCallerHasOwnerRole {
    vm.assume(_recipient != address(_entrypoint));
    _validAddress(_recipient);
    vm.assume(_balance != 0);
    vm.deal(address(_entrypoint), _balance);

    uint256 _initialEntrypointBalance = address(_entrypoint).balance;
    uint256 _initialRecipientBalance = _recipient.balance;

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.FeesWithdrawn(IERC20(_ETH), _recipient, _balance);

    _entrypoint.withdrawFees(IERC20(_ETH), _recipient);

    assertEq(address(_entrypoint).balance, _initialEntrypointBalance - _balance);
    assertEq(_recipient.balance, _initialRecipientBalance + _balance);
  }

  /**
   * @notice Test that the Entrypoint reverts when the ETH transfer fails
   */
  function test_WithdrawFeesWhenETHTransferFails(uint256 _balance, address _recipient) external givenCallerHasOwnerRole {
    vm.assume(_recipient != address(_entrypoint));
    _validAddress(_recipient);
    vm.assume(_balance != 0);
    vm.deal(address(_entrypoint), _balance);

    // Deploy reverting contract at recipient address
    bytes memory revertingCode = hex'60006000fd'; // PUSH1 0x00 PUSH1 0x00 REVERT
    vm.etch(_recipient, revertingCode);

    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.ETHTransferFailed.selector));
    _entrypoint.withdrawFees(IERC20(_ETH), _recipient);
  }

  /**
   * @notice Test that the Entrypoint withdraws fees for a token
   */
  function test_WithdrawFeesWhenTokenBalanceExists(
    address _asset,
    uint256 _balance,
    address _recipient
  ) external givenCallerHasOwnerRole {
    vm.assume(_recipient != address(_entrypoint));
    vm.assume(_balance != 0);
    vm.assume(_asset != _ETH);
    _validAddress(_recipient);
    _validAddress(_asset);
    vm.deal(address(_entrypoint), _balance);

    _mockAndExpect(
      _asset, abi.encodeWithSelector(IERC20.balanceOf.selector, address(_entrypoint)), abi.encode(_balance)
    );

    _mockAndExpect(_asset, abi.encodeWithSelector(IERC20.transfer.selector, _recipient, _balance), abi.encode(true));

    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.FeesWithdrawn(IERC20(_asset), _recipient, _balance);

    _entrypoint.withdrawFees(IERC20(_asset), _recipient);
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_WithdrawFeesWhenCallerLacksOwnerRole(address _caller, address _asset, address _recipient) external {
    vm.assume(_caller != _OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, _entrypoint.OWNER_ROLE()
      )
    );
    vm.prank(_caller);
    _entrypoint.withdrawFees(IERC20(_asset), _recipient);
  }
}

/**
 * @notice Unit tests for Entrypoint view methods
 */
contract UnitViewMethods is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint returns the latest root
   */
  function test_LatestRootGivenAssociationSetsExist() external {
    _entrypoint.mockAssociationSets(1, keccak256('ipfsHash'));
    assertEq(_entrypoint.latestRoot(), 1);
  }

  /**
   * @notice Test that the Entrypoint returns the root by index
   */
  function test_RootByIndexGivenValidIndex() external {
    _entrypoint.mockAssociationSets(1, keccak256('ipfsHash'));
    _entrypoint.mockAssociationSets(2, keccak256('ipfsHash'));
    assertEq(_entrypoint.rootByIndex(0), 1);
    assertEq(_entrypoint.rootByIndex(1), 2);
  }
}
