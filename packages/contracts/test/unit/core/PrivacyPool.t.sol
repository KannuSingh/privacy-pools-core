// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from 'forge-std/Test.sol';
import {InternalLeanIMT, LeafAlreadyExists, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IPrivacyPool, PrivacyPool} from 'contracts/PrivacyPool.sol';
import {ProofLib} from 'contracts/lib/ProofLib.sol';

import {Constants} from 'test/helper/Constants.sol';

import {IState} from 'interfaces/IState.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

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
    address _verifier,
    address _asset,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) PrivacyPool(_entrypoint, _verifier, _asset, _poseidonT2, _poseidonT3, _poseidonT4) {}

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
    deposits[_label] = Deposit(_depositor, 1, block.timestamp + 1 weeks);
  }

  function mockNullifierStatus(uint256 _nullifierHash, IState.NullifierStatus _status) external {
    nullifierHashes[_nullifierHash] = _status;
  }

  function insertLeafInShadowTree(uint256 _leaf) external returns (uint256 _root) {
    _root = merkleTreeCopy._insert(_leaf);
  }

  function insertLeaf(uint256 _leaf) external returns (uint256 _root) {
    _root = _merkleTree._insert(_leaf);
  }
}

/**
 * @notice Base test contract for the PrivacyPool
 * @dev Implements common setup and helpers for unit tests
 */
contract UnitPrivacyPool is Test {
  using ProofLib for ProofLib.Proof;

  PoolForTest internal _pool;
  uint256 internal _scope;

  address internal immutable _ENTRYPOINT = makeAddr('entrypoint');
  address internal immutable _VERIFIER = makeAddr('verifier');
  address internal immutable _ASSET = makeAddr('asset');
  address internal immutable _POSEIDON_T2 = makeAddr('poseidonT2');
  address internal immutable _POSEIDON_T3 = makeAddr('poseidonT3');
  address internal immutable _POSEIDON_T4 = makeAddr('poseidonT4');

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

  modifier givenValidProof(IPrivacyPool.Withdrawal memory _w, ProofLib.Proof memory _p) {
    _p.pubSignals[0] = bound(_p.pubSignals[0], 1, type(uint256).max);
    _p.pubSignals[1] = bound(_p.pubSignals[1], 1, type(uint256).max);
    _p.pubSignals[3] = bound(_p.pubSignals[2], 1, type(uint256).max);
    _p.pubSignals[6] = bound(_p.pubSignals[6], 1, type(uint256).max);
    _p.pubSignals[7] = bound(_p.pubSignals[7], 1, Constants.SNARK_SCALAR_FIELD - 1);

    _p.pubSignals[5] = uint256(keccak256(abi.encode(_w, _scope)));

    _;
  }

  modifier givenKnownStateRoot(uint256 _stateRoot) {
    _pool.mockKnownStateRoot(_stateRoot);
    _;
  }

  modifier givenLatestASPRoot(uint256 _aspRoot) {
    vm.mockCall(_ENTRYPOINT, abi.encodeWithSignature('latestRoot()'), abi.encode(_aspRoot));
    vm.expectCall(_ENTRYPOINT, abi.encodeWithSignature('latestRoot()'));
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
    _pool = new PoolForTest(_ENTRYPOINT, _VERIFIER, _ASSET, _POSEIDON_T2, _POSEIDON_T3, _POSEIDON_T4);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _ASSET)));
  }

  /*//////////////////////////////////////////////////////////////
                            HELPERS
  //////////////////////////////////////////////////////////////*/

  function _mockAndExpect(address _contract, bytes memory _call, bytes memory _return) internal {
    vm.mockCall(_contract, _call, _return);
    vm.expectCall(_contract, _call);
  }

  function _mockPoseidonHashes(
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) internal {
    _mockAndExpect(
      _POSEIDON_T2, abi.encodeWithSignature('poseidon(uint256[1])', [_nullifier]), abi.encode(_nullifierHash)
    );
    _mockAndExpect(
      _POSEIDON_T3,
      abi.encodeWithSignature('poseidon(uint256[2])', [_nullifier, _secret]),
      abi.encode(_precommitmentHash)
    );
    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_value, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );
  }
}

/**
 * @notice Unit tests for the constructor
 */
contract UnitConstructor is UnitPrivacyPool {
  /**
   * @notice Test for the constructor given valid addresses
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorGivenValidAddresses(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) external {
    vm.assume(
      _entrypoint != address(0) && _verifier != address(0) && _asset != address(0) && _poseidonT2 != address(0)
        && _poseidonT3 != address(0) && _poseidonT4 != address(0)
    );

    _pool = new PoolForTest(_entrypoint, _verifier, _asset, _poseidonT2, _poseidonT3, _poseidonT4);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _asset)));
    assertEq(address(_pool.ENTRYPOINT()), _entrypoint);
    assertEq(address(_pool.VERIFIER()), _verifier);
    assertEq(_pool.ASSET(), _asset);
    assertEq(_pool.SCOPE(), _scope);
    assertEq(address(_pool.POSEIDON_T2()), _poseidonT2);
    assertEq(address(_pool.POSEIDON_T3()), _poseidonT3);
    assertEq(address(_pool.POSEIDON_T4()), _poseidonT4);
  }

  /**
   * @notice Test for the constructor when any address is zero
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorWhenAnyAddressIsZero(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) external {
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(address(0), _verifier, _asset, _poseidonT2, _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(_entrypoint, address(0), _asset, _poseidonT2, _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _verifier, address(0), _poseidonT2, _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _verifier, _asset, address(0), _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _verifier, _asset, _poseidonT2, address(0), _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new PoolForTest(_entrypoint, _verifier, _asset, _poseidonT2, _poseidonT3, address(0));
  }
}

/**
 * @notice Unit tests for the deposit function
 */
contract UnitDeposit is UnitPrivacyPool {
  /**
   * @notice Test for the deposit function given valid values and commitment
   */
  function test_DepositWhenDepositingValidValueAndCommitment(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_amount > 0);
    vm.assume(_precommitmentHash != 0);

    _commitment = bound(_commitment, 1, Constants.SNARK_SCALAR_FIELD - 1);

    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));

    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_amount, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    _pool.deposit(_depositor, _amount, _precommitmentHash);
    (address _retrievedDepositor, uint256 _retrievedAmount,) = _pool.deposits(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_retrievedAmount, _amount);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function given valid values and existing commitment
   */
  function test_DepositWhenDepositingValidValueAndExistingCommitment(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash,
    uint256 _commitment,
    uint256 _existingCommitment
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_amount > 0);
    vm.assume(_precommitmentHash != 0);
    vm.assume(_existingCommitment != 0);

    _existingCommitment = bound(_existingCommitment, 1, Constants.SNARK_SCALAR_FIELD - 1);
    _commitment = bound(_commitment, 1, Constants.SNARK_SCALAR_FIELD - 1);

    vm.assume(_existingCommitment != _commitment);

    _pool.insertLeafInShadowTree(_existingCommitment);
    _pool.insertLeaf(_existingCommitment);

    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));

    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_amount, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    _pool.deposit(_depositor, _amount, _precommitmentHash);
    (address _retrievedDepositor, uint256 _retrievedAmount,) = _pool.deposits(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_retrievedAmount, _amount);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function when depositing zero value
   */
  function test_DepositWhenDepositingZeroValue(
    address _depositor,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_precommitmentHash != 0);

    uint256 _amount = 0;

    _commitment = bound(_commitment, 1, Constants.SNARK_SCALAR_FIELD - 1);

    uint256 _newRoot = _pool.insertLeafInShadowTree(_commitment);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));

    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_amount, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pulled(_ENTRYPOINT, _amount);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Deposited(_depositor, _commitment, _label, _amount, _newRoot);

    _pool.deposit(_depositor, _amount, _precommitmentHash);
    (address _retrievedDepositor, uint256 _retrievedAmount,) = _pool.deposits(_label);
    assertEq(_retrievedDepositor, _depositor);
    assertEq(_retrievedAmount, _amount);
    assertEq(_pool.nonce(), _nonce + 1);
  }

  /**
   * @notice Test for the deposit function when commitment already exists in the tree
   */
  function test_DepositWhenCommitmentExistsInTree(
    address _depositor,
    uint256 _amount,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsEntrypoint givenPoolIsActive {
    vm.assume(_depositor != address(0));
    vm.assume(_amount > 0);
    vm.assume(_precommitmentHash != 0);

    _commitment = bound(_commitment, 1, Constants.SNARK_SCALAR_FIELD - 1);

    uint256 _nonce = _pool.nonce();
    uint256 _label = uint256(keccak256(abi.encodePacked(_scope, _nonce + 1)));

    _mockAndExpect(
      address(_pool.POSEIDON_T4()),
      abi.encodeWithSignature('poseidon(uint256[3])', [_amount, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

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
}

/**
 * @notice Unit tests for the withdraw function
 */
contract UnitWithdraw is UnitPrivacyPool {
  using ProofLib for ProofLib.Proof;

  function test_WithdrawWhenWithdrawingNonzeroAmount(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    vm.mockCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)), abi.encode(true));
    vm.expectCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)));

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pushed(_w.processooor, _p.pubSignals[0]);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.Withdrawn(_w.processooor, _p.pubSignals[0], _p.pubSignals[6]);

    _pool.withdraw(_w, _p);

    assertEq(uint256(_pool.nullifierHashes(_p.existingNullifierHash())), uint256(IState.NullifierStatus.SPENT));
  }

  function test_WithdrawWhenWithdrawingNullifierAlreadySpent(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    vm.mockCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)), abi.encode(true));
    vm.expectCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)));

    _pool.mockNullifierStatus(_p.existingNullifierHash(), IState.NullifierStatus.SPENT);

    vm.expectRevert(IState.InvalidNullifierStatusChange.selector);
    _pool.withdraw(_w, _p);
  }

  function test_WithdrawWhenWithdrawingNullifierForRagequit(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_p.ASPRoot())
  {
    vm.mockCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)), abi.encode(true));
    vm.expectCall(_VERIFIER, abi.encodeCall(IVerifier.verifyProof, (_p)));

    _pool.mockNullifierStatus(_p.existingNullifierHash(), IState.NullifierStatus.RAGEQUIT_PENDING);

    vm.expectRevert(IState.InvalidNullifierStatusChange.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the ASPRoot is outdated
   */
  function test_WithdrawWhenASPRootIsOutdated(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p,
    uint256 _unknownASPRoot
  )
    external
    givenCallerIsProcessooor(_w.processooor)
    givenValidProof(_w, _p)
    givenKnownStateRoot(_p.stateRoot())
    givenLatestASPRoot(_unknownASPRoot)
  {
    vm.assume(_unknownASPRoot != _p.ASPRoot());
    vm.expectRevert(IPrivacyPool.IncorrectASPRoot.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the state root is unknown
   */
  function test_WithdrawWhenStateRootUnknown(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p
  ) external givenCallerIsProcessooor(_w.processooor) givenValidProof(_w, _p) {
    vm.expectRevert(IPrivacyPool.UnknownStateRoot.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the proof scope mismatches
   */
  function test_WithdrawWhenProofContextMismatches(
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p,
    uint256 _unknownContext
  ) external givenCallerIsProcessooor(_w.processooor) givenValidProof(_w, _p) {
    vm.assume(_unknownContext != uint256(keccak256(abi.encode(_w, _scope))));
    _p.pubSignals[5] = _unknownContext;
    vm.expectRevert(IPrivacyPool.ContextMismatch.selector);
    _pool.withdraw(_w, _p);
  }

  /**
   * @notice Test for the withdraw function when the caller is not the processooor
   */
  function test_WithdrawWhenCallerIsNotProcessooor(
    address _caller,
    IPrivacyPool.Withdrawal memory _w,
    ProofLib.Proof memory _p
  ) external {
    vm.assume(_caller != _w.processooor);
    vm.expectRevert(IPrivacyPool.InvalidProcesooor.selector);
    vm.prank(_caller);
    _pool.withdraw(_w, _p);
  }
}

/**
 * @notice Unit tests for the ragequit function
 */
contract UnitInitiateRagequit is UnitPrivacyPool {
  /**
   * @notice Test for the ragequit function when the nullifier is not spent
   */
  function test_InitiateRagequitWhenNullifierNotSpentAndCooldownElapsed(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _mockAndExpect(
      _POSEIDON_T2, abi.encodeWithSignature('poseidon(uint256[1])', [_nullifier]), abi.encode(_nullifierHash)
    );

    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_value, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.RagequitInitiated(_depositor, _commitment, _label, _value);

    _pool.initiateRagequit(_value, _label, _precommitmentHash, _nullifier);
    assertEq(uint256(_pool.nullifierHashes(_nullifierHash)), uint256(IState.NullifierStatus.RAGEQUIT_PENDING));
  }

  /**
   * @notice Test for the ragequit function when the nullifier is already spent
   */
  function test_InitiateRagequitWhenNullifierAlreadySpent(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _mockAndExpect(
      _POSEIDON_T2, abi.encodeWithSignature('poseidon(uint256[1])', [_nullifier]), abi.encode(_nullifierHash)
    );

    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_value, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    _pool.mockNullifierStatus(_nullifierHash, IState.NullifierStatus.SPENT);
    vm.expectRevert(IState.InvalidNullifierStatusChange.selector);
    _pool.initiateRagequit(_value, _label, _precommitmentHash, _nullifier);
  }

  /**
   * @notice Test for the ragequit function when the commitment is not in the state
   */
  function test_InitiateRagequitWhenCommitmentNotInState(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) {
    _mockAndExpect(
      _POSEIDON_T2, abi.encodeWithSignature('poseidon(uint256[1])', [_nullifier]), abi.encode(_nullifierHash)
    );
    _mockAndExpect(
      _POSEIDON_T4,
      abi.encodeWithSignature('poseidon(uint256[3])', [_value, _label, _precommitmentHash]),
      abi.encode(_commitment)
    );

    vm.expectRevert(IPrivacyPool.InvalidCommitment.selector);
    _pool.initiateRagequit(_value, _label, _precommitmentHash, _nullifier);
  }

  /**
   * @notice Test for the ragequit function when the caller is not the original depositor
   */
  function test_InitiateRagequitWhenCallerIsNotOriginalDepositor(
    address _caller,
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _precommitmentHash
  ) external {
    vm.assume(_caller != _depositor);
    _pool.mockDeposit(_depositor, _label);
    vm.expectRevert(IPrivacyPool.OnlyOriginalDepositor.selector);
    vm.prank(_caller);
    _pool.initiateRagequit(_value, _label, _precommitmentHash, _nullifier);
  }
}

/**
 * @notice Unit tests for the ragequit function
 */
contract UnitFinalizeRagequit is UnitPrivacyPool {
  /**
   * @notice Test for the ragequit function when the nullifier is not spent
   */
  function test_FinalizeRagequitWhenNullifierNotSpent(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _mockPoseidonHashes(_value, _label, _nullifier, _secret, _nullifierHash, _precommitmentHash, _commitment);
    _pool.mockNullifierStatus(_nullifierHash, IState.NullifierStatus.RAGEQUIT_PENDING);

    vm.expectEmit(address(_pool));
    emit PoolForTest.Pushed(_depositor, _value);

    vm.expectEmit(address(_pool));
    emit IPrivacyPool.RagequitFinalized(_depositor, _commitment, _label, _value);

    vm.warp(block.timestamp + 1 weeks);

    _pool.finalizeRagequit(_value, _label, _nullifier, _secret);
    assertEq(uint256(_pool.nullifierHashes(_nullifierHash)), uint256(IState.NullifierStatus.RAGEQUIT_FINALIZED));
  }
  /**
   * @notice Test for the ragequit function when the nullifier is already spent
   */

  function test_FinalizeRagequitWhenNotRagequitteableYet(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _precommitmentHash,
    uint256 _commitment,
    uint256 _timestamp
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _timestamp = bound(_timestamp, block.timestamp, block.timestamp + 1 weeks - 1);

    vm.warp(_timestamp);

    vm.expectRevert(IState.NotYetRagequitteable.selector);
    _pool.finalizeRagequit(_value, _label, _precommitmentHash, _nullifier);
  }
  /**
   * @notice Test for the ragequit function when the nullifier is not pending for ragequit
   */

  function test_FinalizeRagequitWhenNullifierNotRagequitPending(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _mockPoseidonHashes(_value, _label, _nullifier, _secret, _nullifierHash, _precommitmentHash, _commitment);
    _pool.mockNullifierStatus(_nullifierHash, IState.NullifierStatus.NONE);
    vm.warp(block.timestamp + 1 weeks);
    vm.expectRevert(IState.InvalidNullifierStatusChange.selector);
    _pool.finalizeRagequit(_value, _label, _nullifier, _secret);
  }

  /**
   * @notice Test for the ragequit function when the nullifier is already spent
   */
  function test_FinalizeRagequitWhenNullifierAlreadySpent(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) givenCommitmentExistsInState(_commitment) {
    _mockPoseidonHashes(_value, _label, _nullifier, _secret, _nullifierHash, _precommitmentHash, _commitment);
    _pool.mockNullifierStatus(_nullifierHash, IState.NullifierStatus.SPENT);
    vm.warp(block.timestamp + 1 weeks);
    vm.expectRevert(IState.InvalidNullifierStatusChange.selector);
    _pool.finalizeRagequit(_value, _label, _nullifier, _secret);
  }

  /**
   * @notice Test for the ragequit function when the commitment is not in the state
   */
  function test_FinalizeRagequitWhenCommitmentNotInState(
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret,
    uint256 _nullifierHash,
    uint256 _precommitmentHash,
    uint256 _commitment
  ) external givenCallerIsOriginalDepositor(_depositor, _label) {
    _mockPoseidonHashes(_value, _label, _nullifier, _secret, _nullifierHash, _precommitmentHash, _commitment);
    vm.warp(block.timestamp + 1 weeks);

    vm.expectRevert(IPrivacyPool.InvalidCommitment.selector);
    _pool.finalizeRagequit(_value, _label, _nullifier, _secret);
  }

  /**
   * @notice Test for the ragequit function when the caller is not the original depositor
   */
  function test_FinalizeRagequitWhenCallerIsNotOriginalDepositor(
    address _caller,
    address _depositor,
    uint256 _value,
    uint256 _label,
    uint256 _nullifier,
    uint256 _secret
  ) external {
    vm.assume(_caller != _depositor);
    _pool.mockDeposit(_depositor, _label);
    vm.expectRevert(IPrivacyPool.OnlyOriginalDepositor.selector);
    vm.prank(_caller);
    _pool.finalizeRagequit(_value, _label, _nullifier, _secret);
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
    vm.expectEmit(address(_pool));
    emit IPrivacyPool.PoolDied();

    _pool.windDown();
    assertEq(_pool.dead(), true);
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
