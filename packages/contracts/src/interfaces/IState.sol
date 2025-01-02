// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IEntrypoint} from 'interfaces/IEntrypoint.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

/**
 * @title IState
 * @notice Interface for the State contract
 */
interface IState {
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
  error NullifierAlreadySpent();

  /*///////////////////////////////////////////////////////////////
                              VIEWS 
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the version of the protocol
   * @return _version The version string
   */
  function VERSION() external view returns (string memory _version);

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
   * @notice Returns the spending status of a nullifier hash
   * @param _nullifierHash The nullifier hash
   * @return _spent The boolean indicating if the nullifier has been spent
   */
  function nullifierHashes(uint256 _nullifierHash) external view returns (bool _spent);

  /**
   * @notice Returns the original depositor that generated a label
   * @param _label The label
   * @return _depositor The original depositor
   */
  function labelToDepositor(uint256 _label) external view returns (address _depositor);
}
