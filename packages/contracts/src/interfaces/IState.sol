// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';

import {IPoseidonT2, IPoseidonT3, IPoseidonT4} from 'interfaces/IPoseidon.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

/**
 * @title IState
 * @notice Interface for the State contract
 */
interface IState {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for the deposit data
   * @param depositor The address of the depositor
   * @param amount The deposited amount
   * @param whenRagequitteable The end of the ragequit cooldown period
   */
  struct Deposit {
    address depositor;
    uint256 amount;
    uint256 whenRagequitteable;
  }

  /*///////////////////////////////////////////////////////////////
                               ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Enum representing statuses of a nullifier
   */
  enum NullifierStatus {
    NONE,
    SPENT, // Nullifier is spent
    RAGEQUIT_PENDING, // Nullifier is being ragequitted
    RAGEQUIT_FINALIZED // Nullifier has been ragequitted

  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when inserting a leaf into the Merkle Tree
   * @param _index The index of the leaf in the tree
   * @param _leaf The leaf value
   * @param _root The updated root
   */
  event LeafInserted(uint256 _index, uint256 _leaf, uint256 _root);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when trying to call a method only available to the Entrypoint
   */
  error OnlyEntrypoint();

  /**
   * @notice Thrown when trying to deposit into a dead pool
   */
  error PoolIsDead();

  /**
   * @notice Thrown when trying to spend a nullifier that has already been spent
   */
  error InvalidNullifierStatusChange();

  /**
   * @notice Thrown when trying to initiate the ragequitting process of a commitment before the waiting period
   */
  error NotYetRagequitteable();

  /*///////////////////////////////////////////////////////////////
                              VIEWS 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the version of the protocol
   * @return _version The version string
   */
  function VERSION() external view returns (string memory _version);

  /**
   * @notice Returns the root history size for root caching
   * @return _size The amount of valid roots to store
   */
  function ROOT_HISTORY_SIZE() external view returns (uint32 _size);

  /**
   * @notice Returns the configured Entrypoint contract
   * @return _entrypoint The Entrypoint contract
   */
  function ENTRYPOINT() external view returns (IEntrypoint _entrypoint);

  /**
   * @notice Returns the configured Verifier contract
   * @return _verifier The Verifier contract
   */
  function VERIFIER() external view returns (IVerifier _verifier);

  /**
   * @notice Returns the current root index
   * @return _index The current index
   */
  function currentRootIndex() external view returns (uint32 _index);

  /**
   * @notice Returns the current label nonce
   * @return _nonce The current nonce
   */
  function nonce() external view returns (uint256 _nonce);

  /**
   * @notice Returns the boolean indicating if the pool is dead
   * @return _dead The dead boolean
   */
  function dead() external view returns (bool _dead);

  /**
   * @notice Returns the root stored at an index
   * @param _index The root index
   * @return _root The root value
   */
  function roots(uint256 _index) external view returns (uint256 _root);

  /**
   * @notice Returns the status of a nullifier hash
   * @param _nullifierHash The nullifier hash
   * @return _status The nullifier hash status
   */
  function nullifierHashes(uint256 _nullifierHash) external view returns (NullifierStatus _status);

  /**
   * @notice Returns the original depositor that generated a label
   * @param _label The label
   * @return _depositor The original depositor
   * @return _amount The amount of deposit
   * @return _whenRagequitteable The timestamp on which the user can initiate the ragequit
   */
  function deposits(uint256 _label)
    external
    view
    returns (address _depositor, uint256 _amount, uint256 _whenRagequitteable);
}
