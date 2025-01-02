// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

// TODO: compile poseidon contract and replace keccak256
// TODO: compile groth16 verifier contracts

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
  IERC20 public immutable ASSET;

  modifier validWithdrawal(Withdrawal memory _w, ProofLib.Proof memory _p) {
    if (msg.sender != _w.processooor) revert InvalidProcesooor();
    if (_p.scope() != SCOPE) revert ScopeMismatch();
    if (_p.context() != uint256(keccak256(abi.encode(_w, SCOPE)))) {
      revert ContextMismatch();
    }
    if (!_isKnownRoot(_p.stateRoot())) revert UnknownStateRoot();
    if (_p.ASPRoot() != ENTRYPOINT.latestRoot()) revert OutdatedASPRoot();
    if (_p.withdrawnAmount() == 0) revert InvalidWithdrawalAmount();
    _;
  }

  constructor(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidon
  ) State(_entrypoint, _verifier, _poseidon) {
    if (_asset == address(0)) revert ZeroAddress();
    if (_verifier == address(0)) revert ZeroAddress();
    if (_poseidon == address(0)) revert ZeroAddress();
    if (_entrypoint == address(0)) revert ZeroAddress();

    ASSET = IERC20(_asset);
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
  ) external payable onlyEntrypoint returns (uint256 _commitmentHash) {
    // Check deposits are enabled
    if (dead) revert PoolIsDead();

    // Compute label
    uint256 _label = uint256(keccak256(abi.encodePacked(SCOPE, ++nonce)));
    labelToDepositor[_label] = _depositor;

    // Compute commitment hash
    _commitmentHash = uint256(keccak256(abi.encodePacked(_value, _label, _precommitmentHash)));

    // Insert commitment in state (revert if already present)
    _insert(_commitmentHash);

    // Pull funds from depositor
    _handleValueInput(msg.sender, _value);

    // TODO: populate event data
    emit Deposited();
  }

  /// @inheritdoc IPrivacyPool
  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external validWithdrawal(_w, _p) {
    // Verify proof with Groth16 verifier
    VERIFIER.verifyProof(_p);

    // Spend nullifier for existing commitment
    _spend(_p.existingNullifierHash());

    // Insert new commitment in state
    _insert(_p.newCommitmentHash());

    // Transfer out funds to procesooor
    _handleValueOutput(_w.processooor, _p.value());

    // TODO: populate event data
    emit Withdrawn();
  }

  /// @inheritdoc IPrivacyPool
  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external {
    // Ensure caller is original depositor
    if (labelToDepositor[_label] != msg.sender) {
      revert OnlyOriginalDepositor();
    }

    // Compute nullifier hash
    uint256 _nullifierHash = uint256(keccak256(abi.encodePacked(_nullifier)));

    // Compute precommitment hash
    uint256 _precommitmentHash = uint256(keccak256(abi.encodePacked(_nullifier, _secret)));

    // Compute commitment hash
    uint256 _commitment = uint256(keccak256(abi.encodePacked(_value, _label, _precommitmentHash)));

    // Check commitment exists in state
    if (!_isInState(_commitment)) {
      revert InvalidCommitment();
    }

    // Spend commitment nullifier
    _spend(_nullifierHash);

    // Transfer funds to ragequitter
    _handleValueOutput(msg.sender, _value);

    // TODO: populate event data
    emit Ragequit();
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
  function _handleValueInput(address _sender, uint256 _value) internal virtual;

  /**
   * @notice Handle sending an asset
   * @dev To be implemented by an asset specific contract
   * @param _recipient The address of the user receiving funds
   * @param _value The amount of asset being sent
   */
  function _handleValueOutput(address _recipient, uint256 _value) internal virtual;
}
