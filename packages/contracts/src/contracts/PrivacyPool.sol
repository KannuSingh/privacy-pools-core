// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from './State.sol';
import {ProofLib} from './lib/ProofLib.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

abstract contract PrivacyPool is State, IPrivacyPool {
  using ProofLib for ProofLib.Proof;

  uint256 public immutable SCOPE;
  IERC20 public immutable ASSET;

  event Deposited();
  event PoolDied();
  event Ragequit();
  event Withdrawn();

  error InvalidCommitment();
  error InvalidNullifier();
  error InvalidProcesooor();

  constructor(
    address _entrypoint,
    address _verifier,
    address _asset,
    address _poseidon
  ) State(_entrypoint, _verifier, _poseidon) {
    ASSET = IERC20(_asset);
    SCOPE = uint256(keccak256(abi.encodePacked(address(this), block.chainid, _asset)));
  }

  // only callable by entrypoint
  function deposit(
    address _depositor,
    uint256 _value,
    uint256 _precommitmentHash
  ) external payable onlyEntrypoint returns (uint256 _commitmentHash) {
    // check deposits are enabled
    require(!dead, PoolIsDead());

    // compute label
    uint256 _label = uint256(keccak256(abi.encodePacked(SCOPE, ++nonce)));
    labelToDepositor[_label] = _depositor;

    // compute commitment hash
    _commitmentHash = uint256(keccak256(abi.encodePacked(_value, _label, _precommitmentHash)));

    // insert commitment in state (revert if already present)
    _insert(_commitmentHash);

    // pull funds from depositor
    _handleValueInput(msg.sender, _value);

    // emit event
    emit Deposited();
  }

  modifier validWithdrawal(Withdrawal memory _w, ProofLib.Proof memory _p) {
    require(msg.sender == _w.procesooor, InvalidProcesooor());
    require(_p.scope() == SCOPE);
    require(_p.context() == uint256(keccak256(abi.encode(_w, SCOPE))));
    require(!_isInState(_p.nullifierHash()));
    require(_isKnownRoot(_p.stateRoot()));
    require(_p.ASPRoot() == ENTRYPOINT.latestRoot());
    _;
  }

  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external validWithdrawal(_w, _p) {
    // verify proof with Groth16 verifier
    VERIFIER.verifyProof(_p);

    // spend nullifier
    _spend(_p.nullifierHash());
    // insert new commitment in state
    _insert(_p.newCommitmentHash());

    // transfer out funds to procesooor
    _handleValueOutput(_w.procesooor, _p.value());

    // emit event
    emit Withdrawn();
  }

  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external {
    require(labelToDepositor[_label] == msg.sender, 'only og depositor can ragequit');

    uint256 _nullifierHash = uint256(keccak256(abi.encodePacked(_nullifier)));

    uint256 _precommitmentHash = uint256(keccak256(abi.encodePacked(_nullifier, _secret)));

    // compute commitment hash using caller address
    uint256 _commitmentHash = uint256(keccak256(abi.encodePacked(_value, _label, _precommitmentHash)));

    // check commitment exists in state
    if (!_isInState(_commitmentHash)) {
      revert InvalidCommitment();
    }

    // spend commitment
    _spend(_nullifierHash);

    // transfer funds to caller
    _handleValueOutput(msg.sender, _value);

    // emit event
    emit Ragequit();
  }

  // only callable by entrypoint
  function windDown() external onlyEntrypoint {
    // check pool is alive
    require(!dead, PoolIsDead());
    // die
    dead = true;

    // emit event
    emit PoolDied();
  }

  // virtual method to override in asset specific implementations
  function _handleValueInput(address _sender, uint256 _value) internal virtual;

  // virtual method to override in asset specific implementations
  function _handleValueOutput(address _recipient, uint256 _value) internal virtual;
}
