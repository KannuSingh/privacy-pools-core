// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {InternalLeanIMT, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';

import {IState} from 'interfaces/IState.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

/**
 * @title State
 * @notice Base contract for the state of a Privacy Pool
 */
abstract contract State is IState {
  using InternalLeanIMT for LeanIMTData;

  /// @inheritdoc IState
  string public constant VERSION = '0.1.0';

  /// @inheritdoc IState
  IEntrypoint public immutable ENTRYPOINT;
  /// @inheritdoc IState
  IVerifier public immutable VERIFIER;
  /// @inheritdoc IState
  uint256 public nonce;
  /// @inheritdoc IState
  bool public dead;

  address private immutable _POSEIDON;
  LeanIMTData internal _merkleTree;

  /// @inheritdoc IState
  mapping(uint256 _nullifierHash => bool _spent) public nullifierHashes;
  /// @inheritdoc IState
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

  /**
   * @notice Stores a nullifier hash as spent
   * @param _nullifierHash The nullifier hash to spend
   */
  function _spend(uint256 _nullifierHash) internal {
    if (nullifierHashes[_nullifierHash]) revert NullifierAlreadySpent();
    nullifierHashes[_nullifierHash] = true;
  }

  /**
   * @notice Inserts a leaf into the state
   * @dev Reverts if the leaf is already in the state
   * @param _leaf The leaf to insert
   */
  function _insert(uint256 _leaf) internal {
    _merkleTree._insert(_leaf);
  }

  /**
   * @notice Returns whether the root is a known root
   * @param _root The root to check
   */
  // TODO: implement cached roots
  function _isKnownRoot(uint256 _root) internal returns (bool) {}

  /**
   * @notice Returns whether a leaf is in the state
   * @param _leaf The leaf to check
   */
  function _isInState(uint256 _leaf) internal view returns (bool) {
    return _merkleTree._has(_leaf);
  }
}
