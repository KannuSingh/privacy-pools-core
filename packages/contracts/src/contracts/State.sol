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

  // @notice The state merkle tree containing all commitments
  LeanIMTData internal _merkleTree;

  /// @inheritdoc IState
  mapping(uint256 _nullifierHash => NullifierStatus _spent) public nullifierHashes;
  /// @inheritdoc IState
  mapping(uint256 _label => Deposit _deposit) public deposits;

  /**
   * @notice Check the caller is the Entrypoint
   */
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
   * @notice Updates a nullifier hash status
   * @param _nullifierHash The nullifier hash to update
   */
  function _process(uint256 _nullifierHash, NullifierStatus _new) internal {
    // Fetch current nullifier hash status
    NullifierStatus _current = nullifierHashes[_nullifierHash];

    // Withdrawal = none -> spent
    bool _withdrawPath = _current == NullifierStatus.NONE && _new == NullifierStatus.SPENT;

    // Initialize ragequit = none -> pending ragequit
    bool _initRagequitPath = _current == NullifierStatus.NONE && _new == NullifierStatus.RAGEQUIT_PENDING;

    // Finalize ragequit = pending ragequit -> finalized ragequit
    bool _finalizeRagequitPath =
      _current == NullifierStatus.RAGEQUIT_PENDING && _new == NullifierStatus.RAGEQUIT_FINALIZED;

    // Check status change is a known valid one
    if (!(_withdrawPath || _initRagequitPath || _finalizeRagequitPath)) revert InvalidNullifierStatusChange();

    // Store new status
    nullifierHashes[_nullifierHash] = _new;
  }

  /**
   * @notice Inserts a leaf into the state
   * @dev Reverts if the leaf is already in the state. Deletes the oldest known root
   * @param _leaf The leaf to insert
   */
  function _insert(uint256 _leaf) internal returns (uint256 _updatedRoot) {
    // Insert leaf in the tree
    _updatedRoot = _merkleTree._insert(_leaf);

    // Calculate the new root index (circular buffer)
    uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;

    // Update the current root index
    currentRootIndex = newRootIndex;

    // Store the new root at the new index
    roots[newRootIndex] = _updatedRoot;

    emit LeafInserted(_merkleTree.size, _leaf, _updatedRoot);
  }

  /**
   * @notice Returns whether the root is a known root
   * @param _root The root to check
   */
  function _isKnownRoot(uint256 _root) internal view returns (bool _known) {
    if (_root == 0) return false;

    // Iterate the root circular buffer to find the root
    for (uint32 _i = 1; _i <= ROOT_HISTORY_SIZE; ++_i) {
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
