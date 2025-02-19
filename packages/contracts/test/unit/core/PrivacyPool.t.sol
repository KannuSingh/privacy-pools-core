// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Test} from 'forge-std/Test.sol';
import {InternalLeanIMT, LeafAlreadyExists, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {PoseidonT4} from 'poseidon/PoseidonT4.sol';

import {IPrivacyPool, PrivacyPool} from 'contracts/PrivacyPool.sol';
import {ProofLib} from 'contracts/lib/ProofLib.sol';

import {Constants} from 'test/helper/Constants.sol';

import {IState} from 'interfaces/IState.sol';

/**
 * @notice Test contract for the PrivacyPool
 * @dev Implements mock functions to alter state and emit events
 */
contract PoolForTest is PrivacyPool {
  using InternalLeanIMT for LeanIMTData;

  event Pulled(address _sender, uint256 _value);
  event Pushed(address _recipient, uint256 _value);

  LeanIMTData public merkleTreeCopy;

  constructor(
    address _entrypoint,
    address _withdrawalVerifier,
    address _ragequitVerifier,
    address _asset
  ) PrivacyPool(_entrypoint, _withdrawalVerifier, _ragequitVerifier, _asset) {}

  function _pull(address _sender, uint256 _value) internal override {
    emit Pulled(_sender, _value);
  }

  function _push(address _recipient, uint256 _value) internal override {
    emit Pushed(_recipient, _value);
  }

  function mockDead() external {
    dead = true;
  }

  function mockActive() external {
    dead = false;
  }

  function mockLeafAlreadyExists(uint256 _commitment) external {
    _merkleTree.leaves[_commitment] = 1;
  }

  function mockKnownStateRoot(uint256 _stateRoot) external {
    roots[1] = _stateRoot;
  }

  function mockDeposit(address _depositor, uint256 _label) external {
    depositors[_label] = _depositor;
    depositors[_label] = _depositor;
  }

  function mockNullifierStatus(uint256 _nullifierHash, bool _spent) external {
    nullifierHashes[_nullifierHash] = _spent;
  }

  function insertLeafInShadowTree(uint256 _leaf) external returns (uint256 _root) {
    _root = merkleTreeCopy._insert(_leaf);
  }

  function insertLeaf(uint256 _leaf) external returns (uint256 _root) {
    _root = _merkleTree._insert(_leaf);
  }

  function mockTreeDepth(uint256 _depth) external {
    _merkleTree.depth = _depth;
  }

  function mockTreeSize(uint256 _size) external {
    _merkleTree.size = _size;
  }

  function mockCurrentRoot(uint256 _root) external {
    _merkleTree.sideNodes[_merkleTree.depth] = _root;
  }
}

/**
 * @notice Base test contract for the PrivacyPool
 * @dev Implements common setup and helpers for unit tests
 */
contract UnitPrivacyPool is Test {
  using ProofLib for ProofLib.WithdrawProof;

  PoolForTest internal _pool;
  uint256 internal _scope;

  address internal immutable _ENTRYPOINT = makeAddr('entrypoint');
  address internal immutable _WITHDRAWAL_VERIFIER = makeAddr('withdrawalVerifier');
  address internal immutable _RAGEQUIT_VERIFIER = makeAddr('ragequitVerifier');
  address internal immutable _ASSET = makeAddr('asset');

  /*//////////////////////////////////////////////////////////////
                            MODIFIERS
  //////////////////////////////////////////////////////////////*/

  modifier givenCallerIsEntrypoint() {
    vm.startPrank(_ENTRYPOINT);
    _;
    vm.stopPrank();
  }

  modifier givenCallerIsProcessooor(address _processooor) {
    vm.startPrank(_processooor);
    _;
    vm.stopPrank();
  }

  modifier givenValidProof(IPrivacyPool.Withdrawal memory _w, ProofLib.WithdrawProof memory _p) {
    // New commitment hash
    _p.pubSignals[0] = bound(_p.pubSignals[0], 1, Constants.SNARK_SCALAR_FIELD - 1);

    // Existing nullifier hash
    _p.pubSignals[1] = bound(_p.pubSignals[1], 1, type(uint256).max) % Constants.SNARK_SCALAR_FIELD;

    // Withdrawn value
    _p.pubSignals[2] = bound(_p.pubSignals[2], 1, type(uint256).max) % Constants.SNARK_SCALAR_FIELD;

    // State root
    _p.pubSignals[3] = bound(_p.pubSignals[3], 1, type(uint256).max) % Constants.SNARK_SCALAR_FIELD;

    // State tree depth
    _p.pubSignals[4] = bound(_p.pubSignals[4], 1, 32);

    // ASP tree depth
    _p.pubSignals[6] = bound(_p.pubSignals[6], 1, 32);

    // Context
    _p.pubSignals[7] = uint256(keccak256(abi.encode(_w, _scope))) % Constants.SNARK_SCALAR_FIELD;

    _;
  }

  modifier givenKnownStateRoot(uint256 _stateRoot) {
    vm.assume(_stateRoot != 0);
    _pool.mockKnownStateRoot(_stateRoot);
    _;
  }

  modifier givenLatestASPRoot(uint256 _aspRoot) {
    _mockAndExpect(_ENTRYPOINT, abi.encodeWithSignature('latestRoot()'), abi.encode(_aspRoot));
    _;
  }

  modifier givenCallerIsOriginalDepositor(address _depositor, uint256 _label) {
    vm.assume(_depositor != address(0));
    vm.assume(_label != 0);

    _pool.mockDeposit(_depositor, _label);

    vm.startPrank(_depositor);
    _;
    vm.stopPrank();
  }

  modifier givenCommitmentExistsInState(uint256 _commitment) {
    _pool.mockLeafAlreadyExists(_commitment);
    _;
  }

  modifier givenPoolIsDead() {
    _pool.mockDead();
    _;
  }

  modifier givenPoolIsActive() {
    _pool.mockActive();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                            SETUP
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    _pool = new PoolForTest(_ENTRYPOINT, _WITHDRAWAL_VERIFIER, _RAGEQUIT_VERIFIER, _ASSET);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _ASSET))) % Constants.SNARK_SCALAR_FIELD;
  }

  /*//////////////////////////////////////////////////////////////
                            HELPERS
  //////////////////////////////////////////////////////////////*/

  function _assumeFuzzable(address _address) internal pure {
    assumeNotForgeAddress(_address);
    assumeNotZeroAddress(_address);
    assumeNotPrecompile(_address);
  }

  function _mockAndExpect(address _contract, bytes memory _call, bytes memory _return) internal {
    vm.mockCall(_contract, _call, _return);
    vm.expectCall(_contract, _call);
  }
}

/**
 * @notice Unit tests for the constructor
 */
contract UnitConstructor is UnitPrivacyPool {
  /**
   * @notice Test that the pool correctly initializes with valid constructor parameters
   */
  function test_ConstructorGivenValidAddresses(
    address _entrypoint,
    address _withdrawalVerifier,
    address _ragequitVerifier,
    address _asset
  ) external {
    // Ensure all addresses are non-zero
    _assumeFuzzable(_entrypoint);
    _assumeFuzzable(_withdrawalVerifier);
    _assumeFuzzable(_ragequitVerifier);
    _assumeFuzzable(_asset);
    vm.assume(
      _entrypoint != address(0) && _withdrawalVerifier != address(0) && _ragequitVerifier != address(0)
        && _asset != address(0)
    );

    // Deploy new pool and compute its scope
    _pool = new PoolForTest(_entrypoint, _withdrawalVerifier, _ragequitVerifier, _asset);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _asset))) % Constants.SNARK_SCALAR_FIELD;

    // Verify all constructor parameters are set correctly
    assertEq(address(_pool.ENTRYPOINT()), _entrypoint, 'Entrypoint address should match constructor input');
    assertEq(
      address(_pool.WITHDRAWAL_VERIFIER()),
      _withdrawalVerifier,
      'Withdrawal verifier address should match constructor input'
    );
    assertEq(
      address(_pool.RAGEQUIT_VERIFIER()), _ragequitVerifier, 'Ragequit verifier address should match constructor input'
    );
    assertEq(_pool.ASSET(), _asset, 'Asset address should match constructor input');
    assertEq(_pool.SCOPE(), _scope, 'Scope should be computed correctly');
  }

  /**
   * @notice Test for the constructor when any address is zero
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorWhenAnyAddressIsZero(
    address _entrypoint,
    address _withdrawalVerifier,
    address _ragequitVerifier,
    address _asset
  ) external {
    vm.expectRevert(IState.ZeroAddress.selector);
    new PoolForTest(address(0), _withdrawalVerifier, _ragequitVerifier, _asset);
    vm.expectRevert(IState.ZeroAddress.selector);
    new PoolForTest(_entrypoint, address(0), _ragequitVerifier, _asset);
    vm.expectRevert(IState.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _withdrawalVerifier, address(0), _asset);
    vm.expectRevert(IState.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _withdrawalVerifier, _ragequitVerifier, address(0));
  }
}

/**
 * @notice Unit tests for the deposit function
 */
contract UnitDeposit is UnitPrivacyPool {
  /**
   * @notice Test that the pool correctly deposits funds and updates state
   */
  function test_DepositWhenDepositingValidValueAndCommitment(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    // Setup test with valid parameters
    _assumeFuzzable(_depositor);
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);
    vm.assume(_amount > 0);
    _amount = _bound(_amount, 1, type(uint128).max - 1);

    // Calculate expected values for deposit
    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1))) % Constants.SNARK_SCALAR_FIELD;
    uint256 _commitment = PoseidonT4.hash([_amount, _label, _precommitmentHash]);
    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    // Expect pull and deposit events
    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);
    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    // Execute deposit operation
    _pool.deposit(_depositor, _amount, _precommitmentHash);

    // Verify deposit was recorded correctly
    address _retrievedDepositor = _pool.depositors(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function given valid values and existing commitment
   */
  function test_DepositWhenDepositingValidValueAndExistingCommitment(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash,
    uint256 _existingCommitment
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);
    vm.assume(_existingCommitment != 0);
    _amount = _bound(_amount, 1, type(uint128).max - 1);

    _existingCommitment = bound(_existingCommitment, 1, Constants.SNARK_SCALAR_FIELD - 1);

    _pool.insertLeafInShadowTree(_existingCommitment);
    _pool.insertLeaf(_existingCommitment);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));
    uint256 _commitment = PoseidonT4.hash([_amount, _label, _precommitmentHash]);
    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    _pool.deposit(_depositor, _amount, _precommitmentHash);
    address _retrievedDepositor = _pool.depositors(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function when depositing zero value
   */
  function test_DepositWhenDepositingZeroValue(
    address _depositor,
    uint256 _precommitmentHash
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);

    uint256 _amount = 0;

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));
    uint256 _commitment = PoseidonT4.hash([_amount, _label, _precommitmentHash]);
    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    _pool.deposit(_depositor, _amount, _precommitmentHash);
    address _retrievedDepositor = _pool.depositors(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function when depositing a value greater than 2**128 
   */
  function test_DepositWhenDepositingReallyBigValue(
    address _depositor,
    uint256 _precommitmentHash,
    uint256 _amount
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);
    _amount = _bound(_amount, type(uint128).max, type(uint256).max);

    vm.expectRevert(IPrivacyPool.InvalidDepositValue.selector);
    _pool.deposit(_depositor, _amount, _precommitmentHash);
  }

  /**
   * @notice Test for the deposit function when commitment already exists in the tree
   */
  function test_DepositWhenCommitmentExistsInTree(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);
    _amount = _bound(_amount, 1, type(uint128).max - 1);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));
    uint256 _commitment = PoseidonT4.hash([_amount, _label, _precommitmentHash]);

    _pool.mockLeafAlreadyExists(_commitment);

    vm.expectRevert(LeafAlreadyExists.selector);
    _pool.deposit(_depositor, _amount, _precommitmentHash);
  }

  /**
   * @notice Test for the deposit function when the pool is dead
   */
  function test_DepositWhenPoolIsDead(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash
  ) external givenCallerIsEntrypoint givenPoolIsDead {
    vm.expectRevert(IState.PoolIsDead.selector);
    _pool.deposit(_depositor, _amount, _precommitmentHash);
  }

  /**
   * @notice Test for the deposit function when the caller is not the entrypoint
   */
  function test_DepositWhenCallerIsNotEntrypoint(
    address _caller,
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash
  ) external {
    vm.assume(_caller != _ENTRYPOINT);
    vm.expectRevert(IState.OnlyEntrypoint.selector);
    vm.prank(_caller);
    _pool.deposit(_depositor, _amount, _precommitmentHash);
  }

  /**
   * @notice Test that deposit reverts when max tree depth is reached
   */
  function test_DepositWhenMaxTreeDepthReached(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);
    _amount = _bound(_amount, 1, type(uint128).max - 1);

    // Mock tree at max capacity
    _pool.mockTreeDepth(32);
    _pool.mockTreeSize(2 ** 32);

    // Attempt deposit that would exceed max depth
    vm.expectRevert(IState.MaxTreeDepthReached.selector);
    _pool.deposit(_depositor, _amount, _precommitmentHash);
  }
}

/**
 * @notice Unit tests for the withdraw function
 */
contract UnitWithdraw is UnitPrivacyPool {
  using ProofLib for ProofLib.WithdrawProof;

  function test_WithdrawWhenWithdrawingNonzeroAmount(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    _mockAndExpect(
      _WITHDRAWAL_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pushed(_w.processooor, _p.pubSignals[2]);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Withdrawn(_w.processooor, _p.pubSignals[2], _p.pubSignals[1], _p.pubSignals[0]);

    _pool.withdraw(_w, _p);

    assertTrue(_pool.nullifierHashes(_p.existingNullifierHash()), 'Nullifier should be spent');
  }

  function test_WithdrawWhenTreeIsFull(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    // Tree is full
    _pool.mockTreeSize(2 ** 32);
    _pool.mockTreeDepth(32);

    _mockAndExpect(
      _WITHDRAWAL_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );

    vm.expectRevert(IState.MaxTreeDepthReached.selector);
    _pool.withdraw(_w, _p);
  }

  function test_WithdrawWhenWithdrawingNullifierAlreadySpent(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    _mockAndExpect(
      _WITHDRAWAL_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[8])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );
    _pool.mockNullifierStatus(_p.existingNullifierHash(), true);

    vm.expectRevert(IState.NullifierAlreadySpent.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the ASPRoot is outdated
   */
  function test_WithdrawWhenASPRootIsOutdated(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p,
    uint256 _unknownASPRoot
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_unknownASPRoot)
  {
    // Ensure ASP root mismatch for test
    vm.assume(_unknownASPRoot != _p.ASPRoot());

    // Expect revert due to outdated ASP root
    vm.expectRevert(IPrivacyPool.IncorrectASPRoot.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the state root is unknown
   */
  function test_WithdrawWhenStateRootUnknown(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  ) external givenCallerIsProcessooor(_w.processooor) givenValidProof(_w, _p) {
    // Attempt withdrawal with unknown state root
    vm.expectRevert(IPrivacyPool.UnknownStateRoot.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the proof scope mismatches
   */
  function test_WithdrawWhenProofContextMismatches(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p,
    uint256 _unknownContext
  ) external givenCallerIsProcessooor(_w.processooor) givenValidProof(_w, _p) {
    // Setup proof with mismatched context
    vm.assume(_unknownContext != uint256(keccak256(abi.encode(_w, _scope))));
    _p.pubSignals[7] = _unknownContext;

    // Expect revert due to context mismatch
    vm.expectRevert(IPrivacyPool.ContextMismatch.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the caller is not the processooor
   */
  function test_WithdrawWhenCallerIsNotProcessooor(
    address _caller,
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  ) external {
    // Setup caller different from processooor
    vm.assume(_caller != _w.processooor);

    // Expect revert due to invalid processooor
    vm.expectRevert(IPrivacyPool.InvalidProcessooor.selector);
    vm.prank(_caller);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test that withdraw reverts when tree depths are invalid
   */
  function test_WithdrawWhenTreeDepthsInvalid(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.WithdrawProof memory _p
  ) external givenCallerIsProcessooor(_w.processooor) givenValidProof(_w, _p) {
    // Set the state tree depth
    _p.pubSignals[4] = 33;
    vm.expectRevert(IPrivacyPool.InvalidTreeDepth.selector);
    _pool.withdraw(_w, _p);

    // Test ASP tree depth > MAX_TREE_DEPTH
    _p.pubSignals[4] = 32; // Reset to valid depth
    _p.pubSignals[6] = 33;

    vm.expectRevert(IPrivacyPool.InvalidTreeDepth.selector);
    _pool.withdraw(_w, _p);
  }
}

/**
 * @notice Unit tests for the ragequit function
 */
contract UnitRagequit is UnitPrivacyPool {
  using ProofLib for ProofLib.RagequitProof;

  /**
   * @notice Test for the ragequit function when the caller is the original depositor
   */
  function test_RagequitHappyPath(
    address _depositor,
    ProofLib.RagequitProof memory _p
  ) external givenCallerIsOriginalDepositor(_depositor, _p.label()) givenCommitmentExistsInState(_p.commitmentHash()) {
    _mockAndExpect(
      _RAGEQUIT_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[5])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );

    uint256 _commitmentHash = _p.commitmentHash();
    uint256 _value = _p.value();
    uint256 _label = _p.label();

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Ragequit(_depositor, _commitmentHash, _label, _value);

    _pool.ragequit(_p);
  }

  /**
   * @notice Test for the ragequit function when the caller is not the original depositor
   */
  function test_RagequitWhenCallerIsNotOriginalDepositor(
    address _caller,
    address _depositor,
    ProofLib.RagequitProof memory _p
  ) external {
    vm.assume(_caller != _depositor);
    _pool.mockDeposit(_depositor, _p.label());
    vm.expectRevert(IPrivacyPool.OnlyOriginalDepositor.selector);
    vm.prank(_caller);
    _pool.ragequit(_p);
  }

  /**
   * @notice Test for the ragequit function when the proof is invalid
   */
  function test_RagequitWhenProofIsInvalid(
    address _depositor,
    ProofLib.RagequitProof memory _p
  ) external givenCallerIsOriginalDepositor(_depositor, _p.label()) givenCommitmentExistsInState(_p.commitmentHash()) {
    _mockAndExpect(
      _RAGEQUIT_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[5])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(false)
    );
    vm.expectRevert(IPrivacyPool.InvalidProof.selector);
    _pool.ragequit(_p);
  }

  /**
   * @notice Test for the ragequit function when the commitment is not in the state
   */
  function test_RagequitWhenCommitmentNotInState(
    address _depositor,
    ProofLib.RagequitProof memory _p
  ) external givenCallerIsOriginalDepositor(_depositor, _p.label()) {
    _mockAndExpect(
      _RAGEQUIT_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[5])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );

    vm.expectRevert(IPrivacyPool.InvalidCommitment.selector);
    _pool.ragequit(_p);
  }

  /**
   * @notice Test for the ragequit function when the nullifier is already spent
   */
  function test_RagequitWhenNullifierSpent(
    address _depositor,
    ProofLib.RagequitProof memory _p
  ) external givenCallerIsOriginalDepositor(_depositor, _p.label()) givenCommitmentExistsInState(_p.commitmentHash()) {
    _mockAndExpect(
      _RAGEQUIT_VERIFIER,
      abi.encodeWithSignature(
        'verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[5])', _p.pA, _p.pB, _p.pC, _p.pubSignals
      ),
      abi.encode(true)
    );
    _pool.mockNullifierStatus(_p.nullifierHash(), true);
    vm.expectRevert(IState.NullifierAlreadySpent.selector);
    _pool.ragequit(_p);
  }
}

/**
 * @notice Unit tests for the windDown function
 */
contract UnitWindDown is UnitPrivacyPool {
  /**
   * @notice Test for the windDown function when the pool is active
   */
  function test_WindDownGivenPoolIsActive() external givenCallerIsEntrypoint {
    // Expect pool died event
    vm.expectEmit(address(_pool));
    emit IPrivacyPool.PoolDied();

    // Execute wind down
    _pool.windDown();

    // Verify pool is marked as dead
    assertEq(_pool.dead(), true, 'Pool should be marked as dead');
  }

  /**
   * @notice Test for the windDown function when the pool is already dead
   */
  function test_WindDownWhenPoolIsAlreadyDead() external givenPoolIsDead givenCallerIsEntrypoint {
    vm.expectRevert(IState.PoolIsDead.selector);
    _pool.windDown();
  }

  /**
   * @notice Test for the windDown function when the caller is not the entrypoint
   */
  function test_WindDownWhenCallerIsNotEntrypoint(address _caller) external {
    vm.assume(_caller != _ENTRYPOINT);
    vm.expectRevert(IState.OnlyEntrypoint.selector);
    vm.prank(_caller);
    _pool.windDown();
  }
}

/**
 * @notice Unit tests for the state view methods
 */
contract UnitStateViews is UnitPrivacyPool {
  /**
   * @notice Test for getting the current state root
   */
  function test_currentRoot(uint256 _root) external {
    _pool.mockCurrentRoot(_root);
    assertEq(_pool.currentRoot(), _root);
  }

  /**
   * @notice Test for getting the current tree depth
   */
  function test_currentTreeDepth(uint256 _depth) external {
    _pool.mockTreeDepth(_depth);
    assertEq(_pool.currentTreeDepth(), _depth);
  }

  /**
   * @notice Test for getting the current tree size
   */
  function test_currentTreeSize(uint256 _size) external {
    _pool.mockTreeSize(_size);
    assertEq(_pool.currentTreeSize(), _size);
  }
}
