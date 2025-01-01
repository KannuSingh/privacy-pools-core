// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from './lib/ProofLib.sol';
import {IERC20} from '@oz/interfaces/IERC20.sol';
import {InternalLeanIMT, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';

interface IVerifier {
  function verifyProof(ProofLib.Proof memory _proof) external returns (bool);
}

abstract contract State {
  using InternalLeanIMT for LeanIMTData;

  IEntrypoint public immutable ENTRYPOINT;
  IVerifier public immutable VERIFIER;
  address private immutable _POSEIDON;
  bool public dead;
  string public constant version = '0.1.0';
  uint256 public nonce;

  LeanIMTData internal merkleTree;

  mapping(uint256 _nullifierHash => bool _used) public nullifierHashes;
  mapping(uint256 _label => address _depositor) public labelToDepositor;

  constructor(address _entrypoint, address _verifier, address _poseidon) {
    ENTRYPOINT = IEntrypoint(_entrypoint);
    VERIFIER = IVerifier(_verifier);
    _POSEIDON = _poseidon;
  }

  error NotEntrypoint();
  error PoolIsDead();

  modifier onlyEntrypoint() {
    require(msg.sender == address(ENTRYPOINT), NotEntrypoint());
    _;
  }

  function _spend(uint256 _nullifierHash) internal {
    require(!nullifierHashes[_nullifierHash], 'nullifier already spent');
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
