// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

// TODO: compile poseidon contract and replace keccak256
// TODO: compile groth16 verifier contracts
abstract contract PrivacyPool is State, IPrivacyPool {
  using ProofLib for ProofLib.Proof;

  uint256 public immutable SCOPE;
  IERC20 public immutable ASSET;

  modifier validWithdrawal(Withdrawal memory _w, ProofLib.Proof memory _p) {
    require(msg.sender == _w.procesooor, InvalidProcesooor());
    require(_p.scope() == SCOPE, ScopeMismatch());
    require(_p.context() == uint256(keccak256(abi.encode(_w, SCOPE))), ContextMismatch());
    require(_isKnownRoot(_p.stateRoot()), UnknownStateRoot());
    require(_p.ASPRoot() == ENTRYPOINT.latestRoot(), OutdatedASPRoot());
    require(_p.withdrawnAmount() > 0, InvalidWithdrawalAmount());
    _;
  }

  constructor(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidon
  ) State(_entrypoint, _verifier, _poseidon) {
    require(_asset != address(0), ZeroAddress());
    require(_verifier != address(0), ZeroAddress());
    require(_poseidon != address(0), ZeroAddress());
    require(_entrypoint != address(0), ZeroAddress());

    ASSET = IERC20(_asset);
    SCOPE = uint256(keccak256(abi.encodePacked(address(this), block.chainid, _asset)));
  }

  /*///////////////////////////////////////////////////////////////
                             USER METHODS 
    //////////////////////////////////////////////////////////////*/

  function deposit(
    address _depositor,
    uint256 _value,
    uint256 _precommitmentHash
  ) external payable onlyEntrypoint returns (uint256 _commitmentHash) {
    // Check deposits are enabled
    require(!dead, PoolIsDead());

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

  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external validWithdrawal(_w, _p) {
    // Verify proof with Groth16 verifier
    VERIFIER.verifyProof(_p);

    // Spend nullifier for existing commitment
    _spend(_p.existingNullifierHash());

    // Insert new commitment in state
    _insert(_p.newCommitmentHash());

    // Transfer out funds to procesooor
    _handleValueOutput(_w.procesooor, _p.value());

    // TODO: populate event data
    emit Withdrawn();
  }

  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external {
    // Ensure caller is original depositor
    require(labelToDepositor[_label] == msg.sender, OnlyOriginalDepositor());

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

  function windDown() external onlyEntrypoint {
    // Check pool is still alive
    require(!dead, PoolIsDead());
    // Die
    dead = true;

    emit PoolDied();
  }

  /*///////////////////////////////////////////////////////////////
                          ASSET OVERRIDES
    //////////////////////////////////////////////////////////////*/

  function _handleValueInput(address _sender, uint256 _value) internal virtual;

  function _handleValueOutput(address _recipient, uint256 _value) internal virtual;
}
