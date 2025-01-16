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
    _assumeFuzzable(_params.pool);
    _assumeFuzzable(_params.asset);
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

  function _assumeFuzzable(address _address) internal pure {
    assumeNotForgeAddress(_address);
    assumeNotZeroAddress(_address);
    assumeNotPrecompile(_address);
  }
}

/**
 * @notice Unit tests for Entrypoint constructor and initializer
 */
contract UnitConstructor is UnitEntrypoint {
  /**
   * @notice Test that the Entrypoint is initialized with version 1
   */
  function test_ConstructorWhenDeployed() external {
    bytes32 _initializableStorageSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    bytes32 _data = vm.load(address(_entrypoint), _initializableStorageSlot);
    uint64 _initialized = uint64(uint256(_data)); // First 64 bits contain _initialized
    assertEq(_initialized, 1, 'Entrypoint should be initialized with value 1');
  }

  /**
   * @notice Test that the Entrypoint correctly assigns OWNER_ROLE and ASP_POSTMAN roles
   */
  function test_InitializeGivenValidOwnerAndAdmin() external {
    assertEq(_entrypoint.hasRole(_entrypoint.OWNER_ROLE(), _OWNER), true, 'Owner should have OWNER_ROLE');
    assertEq(_entrypoint.hasRole(_entrypoint.ASP_POSTMAN(), _POSTMAN), true, 'Postman should have ASP_POSTMAN role');
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
   * @notice Test that the Entrypoint correctly updates root and emits event
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
    assertEq(_retrievedRoot, _root, 'Retrieved root should match input root');
    assertEq(_retrievedIpfsHash, _ipfsHash, 'Retrieved IPFS hash should match input hash');
    assertEq(_retrievedTimestamp, _timestamp, 'Retrieved timestamp should match block timestamp');
    assertEq(_index, 1, 'First root update should have index 1');
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
    _assumeFuzzable(_depositor);

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

    assertEq(
      _depositor.balance, _depositorBalanceBefore - _amount, 'Depositor balance should decrease by deposit amount'
    );
    // Actually, this ETH should end up in the Pool contract, but as we're mocking the ETH forwarding call, the ETH remains in the Entrypoint
    assertEq(address(_entrypoint).balance, _amount, 'Entrypoint should receive the deposit amount');
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

    (, uint256 _minDeposit,) = _entrypoint.assetConfig(IERC20(_params.asset));
    _amount = bound(_amount, 0, _minDeposit - 1);

    _mockAndExpect(
      _params.asset,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _depositor, address(_entrypoint), _amount),
      abi.encode(true)
    );

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
    _assumeFuzzable(_asset);
    vm.assume(_depositor != address(0));
    vm.assume(_asset != address(0));
    vm.assume(_asset != _ETH);

    _mockAndExpect(
      _asset,
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _depositor, address(_entrypoint), _amount),
      abi.encode(true)
    );

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

  receive() external payable {}

  /**
   * @notice Test that the Entrypoint correctly relays ERC20 withdrawal and distributes fees
   */
  function test_RelayERC20GivenValidWithdrawalAndProof(
    RelayParams memory _params,
    ProofLib.Proof memory _proof
  ) external {
    // Test only for ERC20 tokens, not ETH
    vm.assume(_params.asset != _ETH);

    // Set up test environment with mock ERC20 token and privacy pool
    _params.asset = address(new ERC20forTest('Test', 'TEST'));
    _params.pool = address(new PrivacyPoolERC20ForTest());

    // Ensure recipient and fee recipient are valid and different addresses
    _assumeFuzzable(_params.recipient);
    _assumeFuzzable(_params.feeRecipient);

    vm.assume(_params.recipient != _params.feeRecipient);
    vm.assume(_params.recipient != address(_entrypoint));
    vm.assume(_params.feeRecipient != address(_entrypoint));

    // Configure withdrawal parameters within valid bounds
    vm.assume(_params.amount != 0);
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;

    // Construct withdrawal data with fee distribution details
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    // Set up pool and mock necessary interactions
    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    uint256 _amountAfterFees = _deductFee(_params.amount, _params.feeBPS);
    uint256 _feeAmount = _params.amount - _amountAfterFees;
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));

    // Fund the pool with test tokens
    deal(_params.asset, _params.pool, _params.amount);
    PrivacyPoolERC20ForTest(_params.pool).setAsset(_params.asset);

    // Record initial balances for verification
    uint256 _poolBalanceBefore = IERC20(_params.asset).balanceOf(_params.pool);
    uint256 _entrypointBalanceBefore = IERC20(_params.asset).balanceOf(address(_entrypoint));
    uint256 _recipientBalanceBefore = IERC20(_params.asset).balanceOf(_params.recipient);
    uint256 _feeRecipientBalanceBefore = IERC20(_params.asset).balanceOf(_params.feeRecipient);

    // Expect the withdrawal relay event to be emitted
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(
      _params.caller, _params.recipient, IERC20(_params.asset), _params.amount, _feeAmount
    );

    // Execute the relay operation
    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);

    // Verify final balances reflect correct token distribution
    assertEq(
      IERC20(_params.asset).balanceOf(_params.pool),
      _poolBalanceBefore - _params.amount,
      'Pool balance should decrease by withdrawal amount'
    );
    assertEq(
      IERC20(_params.asset).balanceOf(address(_entrypoint)),
      _entrypointBalanceBefore,
      'Entrypoint balance should remain unchanged'
    );
    assertEq(
      IERC20(_params.asset).balanceOf(_params.recipient),
      _recipientBalanceBefore + _amountAfterFees,
      'Recipient should receive amount after fees'
    );
    assertEq(
      IERC20(_params.asset).balanceOf(_params.feeRecipient),
      _feeRecipientBalanceBefore + _feeAmount,
      'Fee recipient should receive fee amount'
    );
  }

  /**
   * @notice Test that the Entrypoint correctly relays ETH withdrawal and distributes fees
   */
  function test_RelayETHGivenValidWithdrawalAndProof(RelayParams memory _params, ProofLib.Proof memory _proof) external {
    // Setup test with valid recipients and amounts
    _assumeFuzzable(_params.recipient);
    _assumeFuzzable(_params.feeRecipient);

    // NOTE: somehow, the PointEvaluation address is not filtered
    vm.assume(_params.recipient != address(10));
    vm.assume(_params.feeRecipient != address(10));

    vm.assume(_params.recipient != _params.feeRecipient);
    vm.assume(_params.recipient != address(_entrypoint));
    vm.assume(_params.feeRecipient != address(_entrypoint));
    vm.assume(_params.amount != 0);

    // Configure ETH pool and parameters
    _params.asset = _ETH;
    _params.pool = address(new PrivacyPoolETHForTest());

    // Set up withdrawal parameters within valid bounds
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;

    // Construct withdrawal data with fee distribution
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    // Setup pool and mock interactions
    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    uint256 _amountAfterFees = _deductFee(_params.amount, _params.feeBPS);
    uint256 _feeAmount = _params.amount - _amountAfterFees;
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));
    deal(_params.pool, _params.amount);

    // Record initial balances for verification
    uint256 _poolBalanceBefore = address(_params.pool).balance;
    uint256 _entrypointBalanceBefore = address(_entrypoint).balance;
    uint256 _recipientBalanceBefore = address(_params.recipient).balance;
    uint256 _feeRecipientBalanceBefore = address(_params.feeRecipient).balance;

    // Expect withdrawal relay event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(
      _params.caller, _params.recipient, IERC20(_params.asset), _params.amount, _feeAmount
    );

    // Execute relay operation
    vm.prank(_params.caller);
    _entrypoint.relay(_withdrawal, _proof);

    // Verify final balances reflect correct ETH distribution
    assertEq(
      address(_params.pool).balance, _poolBalanceBefore - _params.amount, 'Pool balance should decrease by push amount'
    );
    assertEq(address(_entrypoint).balance, _entrypointBalanceBefore, 'Entrypoint balance should remain unchanged');
    assertEq(
      address(_params.recipient).balance,
      _recipientBalanceBefore + _amountAfterFees,
      'Recipient should receive amount after fees'
    );
    assertEq(
      address(_params.feeRecipient).balance,
      _feeRecipientBalanceBefore + _feeAmount,
      'Fee recipient should receive fee amount'
    );
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool state is invalid
   */
  function test_RelayInvalidPoolState(RelayParams memory _params, ProofLib.Proof memory _proof) external {
    // Setup test with valid recipients and amount
    _assumeFuzzable(_params.recipient);
    _assumeFuzzable(_params.feeRecipient);

    // NOTE: somehow, the PointEvaluation address is not filtered
    vm.assume(_params.recipient != address(10));
    vm.assume(_params.feeRecipient != address(10));

    vm.assume(_params.amount != 0);

    // Configure ETH pool with faulty behavior
    _params.asset = _ETH;
    _params.pool = address(new FaultyPrivacyPool());

    // Set up withdrawal parameters within valid bounds
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;

    // Construct withdrawal data with fee distribution
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: address(_entrypoint), scope: _params.scope, data: _data});

    // Fund entrypoint with more than needed to test faulty pool behavior
    deal(address(_entrypoint), _params.amount * 2);
    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));

    // Expect revert due to invalid pool state
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
    // Set withdrawal amount to zero
    _proof.pubSignals[0] = 0;

    // Expect revert due to invalid withdrawal amount
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
    // Ensure non-zero withdrawal amount
    vm.assume(_proof.pubSignals[0] != 0);

    // Expect revert due to pool not found
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
    // Setup test with valid parameters but invalid processooor
    _assumeFuzzable(_params.asset);
    _assumeFuzzable(_params.pool);
    vm.assume(_processooor != address(_entrypoint));
    vm.assume(_params.amount != 0);

    // Configure withdrawal parameters
    _params.feeBPS = bound(_params.feeBPS, 0, 10_000);
    _params.amount = bound(_params.amount, 1, 1e30);
    _proof.pubSignals[0] = _params.amount;

    // Construct withdrawal data with invalid processooor
    bytes memory _data = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBPS
      })
    );
    IPrivacyPool.Withdrawal memory _withdrawal =
      IPrivacyPool.Withdrawal({processooor: _processooor, scope: _params.scope, data: _data});

    // Setup pool and mock interactions
    _entrypoint.mockScopeToPool(_params.scope, _params.pool);
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.ASSET.selector), abi.encode(_params.asset));

    // Mock balance check for ERC20 tokens
    if (_params.asset != _ETH) {
      _mockAndExpect(
        _params.asset,
        abi.encodeWithSelector(IERC20.balanceOf.selector, address(_entrypoint)),
        abi.encode(_params.amount)
      );
    }

    // Expect revert due to invalid processooor
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
    // Setup test with valid pool and asset addresses
    _assumeFuzzable(_pool);
    _assumeFuzzable(_asset);
    _vettingFeeBPS = bound(_vettingFeeBPS, 0, 10_000);

    // Calculate pool scope and mock interactions
    uint256 _scope = uint256(keccak256(abi.encodePacked(_pool, block.chainid, _asset)));
    _mockAndExpect(_pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    // Mock ERC20 approval for non-ETH assets
    if (_asset != _ETH) {
      _mockAndExpect(
        _asset, abi.encodeWithSelector(IERC20.approve.selector, _pool, type(uint256).max), abi.encode(true)
      );
    }

    // Expect pool registration event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolRegistered(IPrivacyPool(_pool), IERC20(_asset), _scope);

    // Execute pool registration
    _entrypoint.registerPool(IERC20(_asset), IPrivacyPool(_pool), _minDeposit, _vettingFeeBPS);

    // Verify pool configuration is set correctly
    (IPrivacyPool _retrievedPool, uint256 _retrievedMinDeposit, uint256 _retrievedFeeBPS) =
      _entrypoint.assetConfig(IERC20(_asset));
    assertEq(address(_retrievedPool), _pool, 'Retrieved pool should match input pool');
    assertEq(_retrievedMinDeposit, _minDeposit, 'Retrieved minimum deposit should match input');
    assertEq(_retrievedFeeBPS, _vettingFeeBPS, 'Retrieved vetting fee should match input');
  }

  /**
   * @notice Test that the Entrypoint reverts when the asset pool is already registered
   */
  function test_RegisterPoolWhenAssetPoolExists(PoolParams memory _params)
    external
    givenCallerHasOwnerRole
    givenPoolExists(_params)
  {
    // Ensure pool address is non-zero
    vm.assume(_params.pool != address(0));

    // Expect revert when trying to register pool for already registered asset
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
    // Setup test with valid addresses and parameters
    _assumeFuzzable(_pool);
    _assumeFuzzable(_asset);
    vm.assume(_vettingFeeBPS <= 10_000);

    // Mock existing pool with same scope
    uint256 _scope = uint256(keccak256(abi.encodePacked(_pool, block.chainid, _asset)));
    _entrypoint.mockScopeToPool(_scope, _pool);
    _mockAndExpect(_pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    // Expect revert when trying to register pool with existing scope
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
    // Setup test with caller different from owner
    vm.assume(_caller != _OWNER);

    // Expect revert when non-owner tries to register pool
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
    // Mock pool scope and interactions
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.SCOPE.selector), abi.encode(_scope));

    // Mock ERC20 approval reset for non-ETH assets
    if (_params.asset != _ETH) {
      _mockAndExpect(_params.asset, abi.encodeWithSelector(IERC20.approve.selector, _params.pool, 0), abi.encode(true));
    }

    // Expect pool removal event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolRemoved(IPrivacyPool(_params.pool), IERC20(_params.asset), _scope);

    // Execute pool removal
    _entrypoint.removePool(IERC20(_params.asset));

    // Verify pool configuration is reset
    (IPrivacyPool _retrievedPool, uint256 _retrievedMinDeposit, uint256 _retrievedFeeBPS) =
      _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(address(_retrievedPool), address(0), 'Pool should be removed');
    assertEq(_retrievedMinDeposit, 0, 'Minimum deposit should be reset to 0');
    assertEq(_retrievedFeeBPS, 0, 'Vetting fee should be reset to 0');
    assertEq(address(_entrypoint.scopeToPool(_scope)), address(0), 'Scope to pool mapping should be cleared');
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_RemovePoolWhenPoolNotFound(address _asset) external givenCallerHasOwnerRole {
    // Expect revert when trying to remove non-existent pool
    vm.expectRevert(abi.encodeWithSelector(IEntrypoint.PoolNotFound.selector));
    _entrypoint.removePool(IERC20(_asset));
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_RemovePoolWhenCallerLacksOwnerRole(address _caller, address _asset) external {
    // Setup test with caller different from owner
    vm.assume(_caller != _OWNER);

    // Expect revert when non-owner tries to remove pool
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
    // Verify initial pool configuration
    (IPrivacyPool _pool, uint256 _minDeposit, uint256 _vettingFeeBPS) = _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(address(_pool), _params.pool, 'Retrieved pool should match input pool');
    assertEq(_minDeposit, _params.minDeposit, 'Retrieved minimum deposit should match input');
    assertEq(_vettingFeeBPS, _params.vettingFeeBPS, 'Retrieved vetting fee should match input');

    _newParams.vettingFeeBPS = bound(_newParams.vettingFeeBPS, 0, 10_000);

    // Expect configuration update event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolConfigurationUpdated(
      IPrivacyPool(_params.pool), IERC20(_params.asset), _newParams.minDeposit, _newParams.vettingFeeBPS
    );

    // Execute configuration update
    _entrypoint.updatePoolConfiguration(IERC20(_params.asset), _newParams.minDeposit, _newParams.vettingFeeBPS);

    // Verify updated configuration
    (, uint256 _newMinDeposit, uint256 _newVettingFeeBPS) = _entrypoint.assetConfig(IERC20(_params.asset));
    assertEq(_newMinDeposit, _newParams.minDeposit, 'Retrieved minimum deposit should match input');
    assertEq(_newVettingFeeBPS, _newParams.vettingFeeBPS, 'Retrieved vetting fee should match input');
  }

  /**
   * @notice Test that the Entrypoint reverts when the pool is not found
   */
  function test_UpdatePoolConfigurationWhenPoolNotFound(
    address _asset,
    uint256 _minDeposit,
    uint256 _vettingFeeBPS
  ) external givenCallerHasOwnerRole {
    _vettingFeeBPS = bound(_vettingFeeBPS, 0, 10_000);
    // Expect revert when trying to update non-existent pool
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
    // Setup test with caller different from owner
    vm.assume(_caller != _OWNER);

    // Expect revert when non-owner tries to update configuration
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
    // Mock pool wind down interaction
    _mockAndExpect(_params.pool, abi.encodeWithSelector(IPrivacyPool.windDown.selector), abi.encode(true));

    // Expect wind down event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.PoolWindDown(IPrivacyPool(_params.pool));

    // Execute pool wind down
    _entrypoint.windDownPool(IPrivacyPool(_params.pool));
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_WindDownPoolWhenCallerLacksOwnerRole(
    address _caller,
    PoolParams memory _params
  ) external givenPoolExists(_params) {
    // Setup test with caller different from owner
    vm.assume(_caller != _OWNER);

    // Expect revert when non-owner tries to wind down pool
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
  receive() external payable {}

  function test_WithdrawFeesWhenETHBalanceExists(uint256 _balance, address _recipient) external givenCallerHasOwnerRole {
    // Setup test with valid recipient and non-zero balance
    _assumeFuzzable(_recipient);
    vm.assume(_recipient != address(10));
    vm.assume(_recipient != address(_entrypoint));
    vm.assume(_balance != 0);
    vm.deal(address(_entrypoint), _balance);

    // Record initial balances for verification
    uint256 _initialEntrypointBalance = address(_entrypoint).balance;
    uint256 _initialRecipientBalance = _recipient.balance;

    // Expect fee withdrawal event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.FeesWithdrawn(IERC20(_ETH), _recipient, _balance);

    // Execute fee withdrawal
    _entrypoint.withdrawFees(IERC20(_ETH), _recipient);

    // Verify balances are updated correctly
    assertEq(
      address(_entrypoint).balance,
      _initialEntrypointBalance - _balance,
      'Depositor balance should decrease by deposit amount'
    );
    assertEq(
      _recipient.balance, _initialRecipientBalance + _balance, 'Recipient balance should increase by deposit amount'
    );
  }

  /**
   * @notice Test that the Entrypoint reverts when the ETH transfer fails
   */
  function test_WithdrawFeesWhenETHTransferFails(uint256 _balance, address _recipient) external givenCallerHasOwnerRole {
    // Setup test with valid recipient and non-zero balance
    _assumeFuzzable(_recipient);
    vm.assume(_recipient != address(_entrypoint));
    vm.assume(_balance != 0);
    vm.deal(address(_entrypoint), _balance);

    // Deploy contract that reverts on ETH receive
    bytes memory revertingCode = hex'60006000fd';
    vm.etch(_recipient, revertingCode);

    // Expect revert when ETH transfer fails
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
    // Setup test with valid parameters
    _assumeFuzzable(_recipient);
    _assumeFuzzable(_asset);
    vm.assume(_recipient != address(_entrypoint));
    vm.assume(_balance != 0);
    vm.assume(_asset != _ETH);
    vm.deal(address(_entrypoint), _balance);

    // Mock token balance and transfer
    _mockAndExpect(
      _asset, abi.encodeWithSelector(IERC20.balanceOf.selector, address(_entrypoint)), abi.encode(_balance)
    );
    _mockAndExpect(_asset, abi.encodeWithSelector(IERC20.transfer.selector, _recipient, _balance), abi.encode(true));

    // Expect fee withdrawal event
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.FeesWithdrawn(IERC20(_asset), _recipient, _balance);

    // Execute fee withdrawal
    _entrypoint.withdrawFees(IERC20(_asset), _recipient);
  }

  /**
   * @notice Test that the Entrypoint reverts when the caller lacks the owner role
   */
  function test_WithdrawFeesWhenCallerLacksOwnerRole(address _caller, address _asset, address _recipient) external {
    // Setup test with caller different from owner
    vm.assume(_caller != _OWNER);

    // Expect revert when non-owner tries to withdraw fees
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
    // Mock association set with root value 1
    _entrypoint.mockAssociationSets(1, keccak256('ipfsHash'));

    // Verify latest root is returned correctly
    assertEq(_entrypoint.latestRoot(), 1, 'Latest root should be 1');
  }

  /**
   * @notice Test that the Entrypoint returns the root by index
   */
  function test_RootByIndexGivenValidIndex() external {
    // Mock multiple association sets with different roots
    _entrypoint.mockAssociationSets(1, keccak256('ipfsHash'));
    _entrypoint.mockAssociationSets(2, keccak256('ipfsHash'));

    // Verify roots are returned correctly by index
    assertEq(_entrypoint.rootByIndex(0), 1, 'First root should be 1');
    assertEq(_entrypoint.rootByIndex(1), 2, 'Second root should be 2');
  }
}
