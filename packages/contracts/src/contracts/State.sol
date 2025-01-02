// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {InternalLeanIMT, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IState} from 'interfaces/IState.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

// TODO: implement cached roots
abstract contract State is IState {
  using InternalLeanIMT for LeanIMTData;

  string public constant VERSION = '0.1.0';

  IEntrypoint public immutable ENTRYPOINT;
  IVerifier public immutable VERIFIER;
  address private immutable _POSEIDON;

  uint256 public nonce;
  bool public dead;
  LeanIMTData internal _merkleTree;

  mapping(uint256 _nullifierHash => bool _used) public nullifierHashes;
  mapping(uint256 _label => address _depositor) public labelToDepositor;

  modifier onlyEntrypoint() {
    if (msg.sender != address(ENTRYPOINT)) revert OnlyEntrypoint();
    _;
  }

  constructor(address _entrypoint, address _verifier, address _poseidon) {
    ENTRYPOINT = IEntrypoint(_entrypoint);
    VERIFIER = IVerifier(_verifier);
    _POSEIDON = _poseidon;
  }

  /*///////////////////////////////////////////////////////////////
                        INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

  function _spend(uint256 _nullifierHash) internal {
    if (nullifierHashes[_nullifierHash]) revert NullifierAlreadySpent();
    nullifierHashes[_nullifierHash] = true;
  }

  function _insert(uint256 _root) internal {
    _merkleTree._insert(_root);
  }

  function _isKnownRoot(uint256 _root) internal returns (bool) {}

  function _isInState(uint256 _leaf) internal view returns (bool) {
    return _merkleTree._has(_leaf);
  }
}
