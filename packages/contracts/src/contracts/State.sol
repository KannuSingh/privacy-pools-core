// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

/*

Made with ♥ for 0xBow by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

import {Constants} from './lib/Constants.sol';
import {InternalLeanIMT, LeanIMTData} from 'lean-imt/InternalLeanIMT.sol';

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IState} from 'interfaces/IState.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

/**
 * @title State
 * @notice Base contract for the managing the state of a Privacy Pool
 * @custom:semver 0.1.0
 */
abstract contract State is IState {
  using InternalLeanIMT for LeanIMTData;

  /// @inheritdoc IState
  uint32 public constant ROOT_HISTORY_SIZE = 30;
  /// @inheritdoc IState
  uint32 public constant MAX_TREE_DEPTH = 32;

  /// @inheritdoc IState
  address public immutable ASSET;
  /// @inheritdoc IState
  uint256 public immutable SCOPE;
  /// @inheritdoc IState
  IEntrypoint public immutable ENTRYPOINT;
  /// @inheritdoc IState
  IVerifier public immutable WITHDRAWAL_VERIFIER;
  /// @inheritdoc IState
  IVerifier public immutable RAGEQUIT_VERIFIER;

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
  mapping(uint256 _nullifierHash => bool _spent) public nullifierHashes;
  /// @inheritdoc IState
  mapping(uint256 _label => address _depositooor) public depositors;

  /**
   * @notice Check the caller is the Entrypoint
   */
  modifier onlyEntrypoint() {
    if (msg.sender != address(ENTRYPOINT)) revert OnlyEntrypoint();
    _;
  }

  /**
   * @notice Initialize the state addresses
   */
  constructor(address _asset, address _entrypoint, address _withdrawalVerifier, address _ragequitVerifier) {
    // Sanitize initial addresses
    if (_asset == address(0)) revert ZeroAddress();
    if (_entrypoint == address(0)) revert ZeroAddress();
    if (_ragequitVerifier == address(0)) revert ZeroAddress();
    if (_withdrawalVerifier == address(0)) revert ZeroAddress();

    // Store asset address
    ASSET = _asset;
    // Compute SCOPE
    SCOPE = uint256(keccak256(abi.encodePacked(address(this), block.chainid, _asset))) % Constants.SNARK_SCALAR_FIELD;

    ENTRYPOINT = IEntrypoint(_entrypoint);
    WITHDRAWAL_VERIFIER = IVerifier(_withdrawalVerifier);
    RAGEQUIT_VERIFIER = IVerifier(_ragequitVerifier);
  }

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IState
  function currentRoot() external view returns (uint256 _root) {
    _root = _merkleTree._root();
  }

  /// @inheritdoc IState
  function currentTreeDepth() external view returns (uint256 _depth) {
    _depth = _merkleTree.depth;
  }

  /// @inheritdoc IState
  function currentTreeSize() external view returns (uint256 _size) {
    _size = _merkleTree.size;
  }

  /*///////////////////////////////////////////////////////////////
                        INTERNAL METHODS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Spends a nullifier hash
   * @param _nullifierHash The nullifier hash to spend
   */
  function _spend(uint256 _nullifierHash) internal {
    // Check if the nullifier is already spent
    if (nullifierHashes[_nullifierHash]) revert NullifierAlreadySpent();

    // Mark as spent
    nullifierHashes[_nullifierHash] = true;
  }

  /**
   * @notice Inserts a leaf into the state
   * @dev Reverts if the leaf is already in the state. Deletes the oldest known root
   * @dev A circular buffer is used for root storage to decrease the cost of storing new roots
   * @param _leaf The leaf to insert
   */
  function _insert(uint256 _leaf) internal returns (uint256 _updatedRoot) {
    // Insert leaf in the tree
    _updatedRoot = _merkleTree._insert(_leaf);

    if (_merkleTree.depth > MAX_TREE_DEPTH) revert MaxTreeDepthReached();

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
   * @dev A circular buffer is used for root storage to decrease the cost of storing new roots
   * @param _root The root to check
   */
  function _isKnownRoot(uint256 _root) internal view returns (bool) {
    if (_root == 0) return false;

    uint32 _currentRootIndex = currentRootIndex;
    uint32 _index = _currentRootIndex;

    // Check ROOT_HISTORY_SIZE indices, starting from current
    for (uint32 _i = 0; _i < ROOT_HISTORY_SIZE; _i++) {
      if (_root == roots[_index]) return true;
      // Move to previous index, wrap to ROOT_HISTORY_SIZE-1 if we go below 0
      _index = _index > 0 ? _index - 1 : ROOT_HISTORY_SIZE - 1;
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
