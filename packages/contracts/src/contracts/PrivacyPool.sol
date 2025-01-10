// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
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
    if (_p.context() != uint256(keccak256(abi.encode(_w, SCOPE)))) {
      revert ContextMismatch();
    }
    if (!_isKnownRoot(_p.stateRoot())) revert UnknownStateRoot();
    if (_p.ASPRoot() != ENTRYPOINT.latestRoot()) revert IncorrectASPRoot();
    if (_p.withdrawnValue() == 0) revert InvalidWithdrawalAmount();
    _;
  }

  constructor(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) State(_entrypoint, _verifier, _poseidonT2, _poseidonT3, _poseidonT4) {
    if (_asset == address(0)) revert ZeroAddress();
    if (_verifier == address(0)) revert ZeroAddress();
    if (_entrypoint == address(0)) revert ZeroAddress();
    if (_poseidonT2 == address(0)) revert ZeroAddress();
    if (_poseidonT3 == address(0)) revert ZeroAddress();
    if (_poseidonT4 == address(0)) revert ZeroAddress();

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
    deposits[_label] = Deposit(_depositor, _value);

    _commitment = POSEIDON_T4.poseidon([_value, _label, _precommitmentHash]);

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

    // Spend nullifier for existing commitment
    _spend(_p.existingNullifierHash());

    // Insert new commitment in state
    _insert(_p.newCommitmentHash());

    // Transfer out funds to procesooor
    _push(_w.processooor, _p.withdrawnValue());

    emit Withdrawn(_w.processooor, _p.withdrawnValue(), _p.existingNullifierHash());
  }

  // TODO: improve without publicly revealing nullifier and secret. maybe add two step
  /// @inheritdoc IPrivacyPool
  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external {
    // Ensure caller is original depositor
    if (deposits[_label].depositor != msg.sender) {
      revert OnlyOriginalDepositor();
    }

    // Compute nullifier hash
    uint256 _nullifierHash = POSEIDON_T2.poseidon([_nullifier]);

    // Compute precommitment hash
    uint256 _precommitmentHash = POSEIDON_T3.poseidon([_nullifier, _secret]);

    // Compute commitment hash
    uint256 _commitment = POSEIDON_T4.poseidon([_value, _label, _precommitmentHash]);

    // Check commitment exists in state
    if (!_isInState(_commitment)) {
      revert InvalidCommitment();
    }

    // Spend commitment nullifier
    _spend(_nullifierHash);

    // Transfer funds to ragequitter
    _push(msg.sender, _value);

    emit Ragequit(msg.sender, _commitment, _value);
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
