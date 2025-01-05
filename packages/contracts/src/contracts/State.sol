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
  uint32 public constant ROOT_HISTORY_SIZE = 30;

  /// @inheritdoc IState
  IEntrypoint public immutable ENTRYPOINT;
  /// @inheritdoc IState
  IVerifier public immutable VERIFIER; // groth16 verifier contract output of snarkjs
  /// @inheritdoc IState
  uint256 public nonce;
  /// @inheritdoc IState
  bool public dead;

  /// @inheritdoc IState
  mapping(uint256 _index => uint256 _root) public roots;
  /// @inheritdoc IState
  uint32 public currentRootIndex;

  LeanIMTData internal _merkleTree;

  /// @inheritdoc IState
  mapping(uint256 _nullifierHash => bool _spent) public nullifierHashes;
  /// @inheritdoc IState
  mapping(uint256 _label => address _depositor) public deposits;

  modifier onlyEntrypoint() {
    if (msg.sender != address(ENTRYPOINT)) revert OnlyEntrypoint();
    _;
  }

  constructor(address _entrypoint, address _verifier) {
    ENTRYPOINT = IEntrypoint(_entrypoint);
    VERIFIER = IVerifier(_verifier);
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
   * @dev Reverts if the leaf is already in the state. Deletes the oldest known root
   * @param _leaf The leaf to insert
   */
  function _insert(uint256 _leaf) internal returns (uint256 _updatedRoot) {
    _updatedRoot = _merkleTree._insert(_leaf);

    uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
    currentRootIndex = newRootIndex;
    roots[newRootIndex] = _updatedRoot;

    delete roots[currentRootIndex - ROOT_HISTORY_SIZE];
  }

  /**
   * @notice Returns whether the root is a known root
   * @param _root The root to check
   */
  function _isKnownRoot(uint256 _root) internal view returns (bool _known) {
    if (_root == 0) {
      return false;
    }

    for (uint32 _i = currentRootIndex; _i < currentRootIndex - ROOT_HISTORY_SIZE; --_i) {
      if (roots[_i] == _root) return true;
    }

    return false;
  }

  /**
   * @notice Returns whether a leaf is in the state
   * @param _leaf The leaf to check
   */
  function _isInState(uint256 _leaf) internal view returns (bool) {
    return _merkleTree._has(_leaf);
  }
}
