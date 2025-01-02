// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from '../contracts/lib/ProofLib.sol';
import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IState} from 'interfaces/IState.sol';

/**
 * @title IPrivacyPool
 * @notice Interface for the PrivacyPool contract
 */
interface IPrivacyPool is IState {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for the withdrawal request
   * @dev The integrity of this data is ensured by the `context` signal in the proof
   * @param processooor The allowed address to process the withdrawal
   * @param data Encoded arbitrary data used by the Entrypoint
   */
  struct Withdrawal {
    address processooor;
    bytes data;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

  // TODO: data TBD
  event Deposited();
  event Withdrawn();
  event Ragequit();

  /**
   * @notice Emitted irreversibly suspending deposits
   */
  event PoolDied();

  /*///////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when trying to spend a commitment that does not exist in the state
   */
  error InvalidCommitment();

  /**
   * @notice Thrown when trying to spend an already spent nullifier
   */
  error InvalidNullifier();

  /**
   * @notice Thrown when calling `withdraw` while not being the allowed processooor
   */
  error InvalidProcesooor();

  /**
   * @notice Thrown when providing an invalid scope for this pool
   */
  error ScopeMismatch();

  /**
   * @notice Thrown when providing an invalid context for the pool and withdrawal
   */
  error ContextMismatch();

  /**
   * @notice Thrown when providing an unknown or outdated state root
   */
  error UnknownStateRoot();

  /**
   * @notice Thrown when providing an outdated ASP root
   */
  error OutdatedASPRoot();

  /**
   * @notice Thrown when trying to ragequit while not being the original depositor
   */
  error OnlyOriginalDepositor();

  /**
   * @notice Thrown when trying to withdraw an invalid amount
   */
  error InvalidWithdrawalAmount();

  /**
   * @notice Thrown when trying to set a state variable as address zero
   */
  error ZeroAddress();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deposit funds into the Privacy Pool
   * @dev Only callable by the Entrypoint
   * @param _depositor The depositor address
   * @param _value The value being deposited
   * @param _precommitment The precommitment hash
   * @return _commitment The commitment hash
   */
  function deposit(
    address _depositor,
    uint256 _value,
    uint256 _precommitment
  ) external payable returns (uint256 _commitment);

  /**
   * @notice Privately withdraw funds by spending an existing commitment
   * @param _w The `Withdrawal` struct
   * @param _p The `Proof` struct
   */
  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external;

  /**
   * @notice Withdraw unapproved funds without privacy
   * @dev Only callable by the original depositor
   * @param _value Value of the existing commitment
   * @param _label Label for a series of related commitments
   * @param _nullifier Existing commitment nullifier
   * @param _secret Existing commitment secret
   */
  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external;

  /**
   * @notice Irreversibly suspends deposits
   * @dev Withdrawals can never be disabled
   * @dev Only callable by the Entrypoint
   */
  function windDown() external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the pool unique identifier
   * @return _scope The scope id
   */
  function SCOPE() external view returns (uint256 _scope);

  /**
   * @notice Returns the pool asset
   * @return _asset The IERC20 cast asset
   */
  function ASSET() external view returns (IERC20 _asset);
}
