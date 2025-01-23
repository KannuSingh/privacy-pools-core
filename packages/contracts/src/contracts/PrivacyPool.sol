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

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {PoseidonT4} from 'poseidon/PoseidonT4.sol';

import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @title PrivacyPool
 * @notice Allows publicly depositing and privately withdrawing funds.
 * @dev Withdrawals require a valid proof of being approved by an ASP.
 * @dev Deposits can be irreversibly suspended by the Entrypoint, while withdrawals can't.
 */
abstract contract PrivacyPool is State, IPrivacyPool {
  using ProofLib for ProofLib.WithdrawProof;
  using ProofLib for ProofLib.RagequitProof;

  /// @inheritdoc IPrivacyPool
  uint256 public immutable SCOPE;

  /// @inheritdoc IPrivacyPool
  address public immutable ASSET;

  modifier validWithdrawal(Withdrawal memory _w, ProofLib.WithdrawProof memory _p) {
    // Check caller is the allowed processooor
    if (msg.sender != _w.processooor) revert InvalidProcesooor();

    // Check the context matches the proof's public signal to ensure its integrity
    if (_p.context() != uint256(keccak256(abi.encode(_w, SCOPE)))) revert ContextMismatch();

    // Check the state root is known
    if (!_isKnownRoot(_p.stateRoot())) revert UnknownStateRoot();

    // Check the ASP root is the latest
    if (_p.ASPRoot() != ENTRYPOINT.latestRoot()) revert IncorrectASPRoot();
    _;
  }

  constructor(
    address _entrypoint,
    address _withdrawalVerifier,
    address _ragequitVerifier,
    address _asset
  ) State(_entrypoint, _withdrawalVerifier, _ragequitVerifier) {
    // Sanitize initial addresses
    if (_asset == address(0)) revert ZeroAddress();
    if (_entrypoint == address(0)) revert ZeroAddress();
    if (_ragequitVerifier == address(0)) revert ZeroAddress();
    if (_withdrawalVerifier == address(0)) revert ZeroAddress();

    // Store asset address
    ASSET = _asset;
    // Compute SCOPE
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
    // Store depositor and ragequit cooldown
    deposits[_label] = Deposit(_depositor, _value, block.timestamp + 1 weeks);

    // Compute commitment hash
    _commitment = PoseidonT4.hash([_value, _label, _precommitmentHash]);

    // Insert commitment in state (revert if already present)
    uint256 _updatedRoot = _insert(_commitment);

    // Pull funds from caller
    _pull(msg.sender, _value);

    emit Deposited(_depositor, _commitment, _label, _value, _updatedRoot);
  }

  /// @inheritdoc IPrivacyPool
  function withdraw(Withdrawal memory _w, ProofLib.WithdrawProof memory _p) external validWithdrawal(_w, _p) {
    // Verify proof with Groth16 verifier
    if (!WITHDRAWAL_VERIFIER.verifyProof(_p)) revert InvalidProof();

    // Mark commitment nullifier as spent
    _spend(_p.existingNullifierHash());

    // Insert new commitment in state
    _insert(_p.newCommitmentHash());

    // Transfer out funds to procesooor
    _push(_w.processooor, _p.withdrawnValue());

    emit Withdrawn(_w.processooor, _p.withdrawnValue(), _p.existingNullifierHash(), _p.newCommitmentHash());
  }

  /// @inheritdoc IPrivacyPool
  function ragequit(ProofLib.RagequitProof memory _p) external {
    // Check if caller is original depositor
    uint256 _label = _p.label();
    if (deposits[_label].depositor != msg.sender) revert OnlyOriginalDepositor();

    // Verify proof with Groth16 verifier
    if (!RAGEQUIT_VERIFIER.verifyProof(_p)) revert InvalidProof();

    // Check commitment exists in state
    if (!_isInState(_p.commitmentHash())) revert InvalidCommitment();

    // Mark nullifier hash as pending for ragequit
    _spend(_p.nullifierHash());

    // Transfer out funds to ragequitter
    _push(msg.sender, _p.value());

    emit Ragequit(msg.sender, _p.commitmentHash(), _p.label(), _p.value());
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
