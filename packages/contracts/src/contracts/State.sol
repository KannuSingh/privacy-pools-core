// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from './lib/ProofLib.sol';
import {IERC20} from '@oz/interfaces/IERC20.sol';
import {InternalLeanIMT, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

abstract contract State {
  using InternalLeanIMT for LeanIMTData;

  uint256 public nonce;
  string public constant version = '0.1.0';
  bool public dead;

  IEntrypoint public immutable ENTRYPOINT;
  IVerifier public immutable VERIFIER;
  address private immutable _POSEIDON;

  LeanIMTData internal merkleTree;

  mapping(uint256 _nullifierHash => bool _used) public nullifierHashes;
  mapping(uint256 _label => address _depositor) public labelToDepositor;

  constructor(address _entrypoint, address _verifier, address _poseidon) {
    ENTRYPOINT = IEntrypoint(_entrypoint);
    VERIFIER = IVerifier(_verifier);
    _POSEIDON = _poseidon;
  }

  error OnlyEntrypoint();
  error PoolIsDead();
  error NullifierAlreadySpent();

  modifier onlyEntrypoint() {
    require(msg.sender == address(ENTRYPOINT), OnlyEntrypoint());
    _;
  }

  function _spend(uint256 _nullifierHash) internal {
    require(!nullifierHashes[_nullifierHash], NullifierAlreadySpent());
    nullifierHashes[_nullifierHash] = true;
  }

  function _insert(uint256 _root) internal {
    merkleTree._insert(_root);
  }

  function _isInState(uint256 _leaf) internal view returns (bool) {
    return merkleTree._has(_leaf);
  }

  function _isKnownRoot(uint256 _root) internal returns (bool) {}
}
