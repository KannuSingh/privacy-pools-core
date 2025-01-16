// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {PoseidonT2} from 'poseidon/PoseidonT2.sol';
import {PoseidonT3} from 'poseidon/PoseidonT3.sol';
import {PoseidonT4} from 'poseidon/PoseidonT4.sol';

import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @title PrivacyPool
 * @notice Allows publicly depositing and privately withdrawing funds.
 * @dev Withdrawals require a valid proof of being approved by an ASP.
 * @dev Deposits can be irreversibly suspended by the Entrypoint, while withdrawals can't.
 */
abstract contract PrivacyPool is State, IPrivacyPool {
  using ProofLib for ProofLib.Proof;

  /// @inheritdoc IPrivacyPool
  uint256 public immutable SCOPE;

  /// @inheritdoc IPrivacyPool
  address public immutable ASSET;

  modifier validWithdrawal(Withdrawal memory _w, ProofLib.Proof memory _p) {
    if (msg.sender != _w.processooor) revert InvalidProcesooor();
    if (_p.context() != uint256(keccak256(abi.encode(_w, SCOPE)))) revert ContextMismatch();
    if (!_isKnownRoot(_p.stateRoot())) revert UnknownStateRoot();
    if (_p.ASPRoot() != ENTRYPOINT.latestRoot()) revert IncorrectASPRoot();
    _;
  }

  constructor(address _entrypoint, address _verifier, address _asset) State(_entrypoint, _verifier) {
    if (_asset == address(0)) revert ZeroAddress();
    if (_verifier == address(0)) revert ZeroAddress();
    if (_entrypoint == address(0)) revert ZeroAddress();

    ASSET = _asset;
    SCOPE = uint256(keccak256(abi.encodePacked(address(this), block.chainid, _asset)));
  }

  /*///////////////////////////////////////////////////////////////
                             USER METHODS 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IPrivacyPool
  function deposit(
    address _depositor,
    uint256 _value,
    uint256 _precommitmentHash
  ) external payable onlyEntrypoint returns (uint256 _commitment) {
    // Check deposits are enabled
    if (dead) revert PoolIsDead();

    // Compute label
    uint256 _label = uint256(keccak256(abi.encodePacked(SCOPE, ++nonce)));
    deposits[_label] = Deposit(_depositor, _value, block.timestamp + 1 weeks);

    _commitment = PoseidonT4.hash([_value, _label, _precommitmentHash]);

    // Insert commitment in state (revert if already present)
    uint256 _updatedRoot = _insert(_commitment);

    // Pull funds from caller
    _pull(msg.sender, _value);

    emit Deposited(_depositor, _commitment, _label, _value, _updatedRoot);
  }

  /// @inheritdoc IPrivacyPool
  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external validWithdrawal(_w, _p) {
    // Verify proof with Groth16 verifier
    if (!VERIFIER.verifyProof(_p)) revert InvalidProof();

    // Mark commitment nullifier as spent
    _process(_p.existingNullifierHash(), NullifierStatus.SPENT);

    // Insert new commitment in state
    _insert(_p.newCommitmentHash());

    // Transfer out funds to procesooor
    _push(_w.processooor, _p.withdrawnValue());

    emit Withdrawn(_w.processooor, _p.withdrawnValue(), _p.existingNullifierHash(), _p.newCommitmentHash());
  }

  /// @inheritdoc IPrivacyPool
  function initiateRagequit(uint256 _value, uint256 _label, uint256 _precommitment, uint256 _nullifier) external {
    // Check if caller is original depositor
    if (deposits[_label].depositor != msg.sender) revert OnlyOriginalDepositor();

    // Compute nullifier hash
    uint256 _nullifierHash = PoseidonT2.hash([_nullifier]);

    // Compute commitment hash
    uint256 _commitment = PoseidonT4.hash([_value, _label, _precommitment]);

    // Check commitment exists in state
    if (!_isInState(_commitment)) revert InvalidCommitment();

    // Mark nullifier hash as pending for ragequit
    _process(_nullifierHash, NullifierStatus.RAGEQUIT_PENDING);

    emit RagequitInitiated(msg.sender, _commitment, _label, _value);
  }

  /// @inheritdoc IPrivacyPool
  function finalizeRagequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external {
    // Check if caller is original depositor
    if (deposits[_label].depositor != msg.sender) revert OnlyOriginalDepositor();
    // Check if ragequit cooldown has elapsed
    if (deposits[_label].whenRagequitteable > block.timestamp) revert NotYetRagequitteable();

    // Compute nullifier hash
    uint256 _nullifierHash = PoseidonT2.hash([_nullifier]);

    // Compute precommitment hash
    uint256 _precommitmentHash = PoseidonT3.hash([_nullifier, _secret]);

    // Compute commitment hash
    uint256 _commitment = PoseidonT4.hash([_value, _label, _precommitmentHash]);

    // Check commitment exists in state
    if (!_isInState(_commitment)) revert InvalidCommitment();

    // Spend ragequitteable nullifier hash
    _process(_nullifierHash, NullifierStatus.RAGEQUIT_FINALIZED);

    // Transfer funds to ragequitter
    _push(msg.sender, _value);

    emit RagequitFinalized(msg.sender, _commitment, _label, _value);
  }

  /*///////////////////////////////////////////////////////////////
                             WIND DOWN
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IPrivacyPool
  function windDown() external onlyEntrypoint {
    // Check pool is still alive
    if (dead) revert PoolIsDead();
    // Die
    dead = true;

    emit PoolDied();
  }

  /*///////////////////////////////////////////////////////////////
                          ASSET OVERRIDES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Handle receiving an asset
   * @dev To be implemented by an asset specific contract
   * @param _sender The address of the user sending funds
   * @param _value The amount of asset being received
   */
  function _pull(address _sender, uint256 _value) internal virtual;

  /**
   * @notice Handle sending an asset
   * @dev To be implemented by an asset specific contract
   * @param _recipient The address of the user receiving funds
   * @param _value The amount of asset being sent
   */
  function _push(address _recipient, uint256 _value) internal virtual;
}
