// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from '../contracts/lib/ProofLib.sol';
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
   * @param scope The unique pool identifier
   * @param data Encoded arbitrary data used by the Entrypoint
   */
  struct Withdrawal {
    address processooor;
    uint256 scope;
    bytes data;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when making a user deposit
   * @param _depositor The address of the depositor
   * @param _commitment The commitment hash
   * @param _label The deposit generated label
   * @param _value The deposited amount
   * @param _merkleRoot The updated merkle root
   */
  event Deposited(address indexed _depositor, uint256 _commitment, uint256 _label, uint256 _value, uint256 _merkleRoot);

  /**
   * @notice Emitted when processing a withdrawal
   * @param _processooor The address which processed the withdrawal
   * @param _value The withdrawn amount
   * @param _spentNullifier The spent nullifier
   */
  event Withdrawn(address indexed _processooor, uint256 _value, uint256 _spentNullifier);

  /**
   * @notice Emitted when initiating the ragequitting process of a commitment
   * @param _ragequitter The address who ragequit
   * @param _commitment The ragequit commitment
   * @param _label The commitment label
   * @param _value The ragequit amount
   */
  event RagequitInitiated(address indexed _ragequitter, uint256 _commitment, uint256 _label, uint256 _value);

  /**
   * @notice Emitted when finalizing the ragequit process of a commitment
   * @param _ragequitter The address who ragequit
   * @param _commitment The ragequit commitment
   * @param _label The commitment label
   * @param _value The ragequit amount
   */
  event RagequitFinalized(address indexed _ragequitter, uint256 _commitment, uint256 _label, uint256 _value);

  /**
   * @notice Emitted irreversibly suspending deposits
   */
  event PoolDied();

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when failing to verify a withdrawal proof through the Groth16 verifier
   */
  error InvalidProof();

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
   * @notice Thrown when providing an unknown or outdated ASP root
   */
  error IncorrectASPRoot();

  /**
   * @notice Thrown when trying to ragequit while not being the original depositor
   */
  error OnlyOriginalDepositor();

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
   * @notice Initiate the ragequitting process of a commitment
   * @dev Only callable by the original depositor
   * @dev The ragequitting process is implemented as a two-step process to avoid frontrunning
   * @param _value Value of the existing commitment
   * @param _label Label for a series of related commitments
   * @param _precommitment Existing commitment's precommitment
   * @param _nullifier Existing commitment nullifier
   */
  function initiateRagequit(uint256 _value, uint256 _label, uint256 _precommitment, uint256 _nullifier) external;

  /**
   * @notice Finalize the ragequitting process of a commitment
   * @dev Only callable by the original depositor
   * @dev The ragequitting process is implemented as a two-step process to avoid frontrunning
   * @param _label Label for a series of related commitments
   * @param _value Value of the existing commitment
   * @param _nullifier Existing commitment nullifier
   * @param _secret Existing commitment secret
   */
  function finalizeRagequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external;

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
   * @return _asset The asset address
   */
  function ASSET() external view returns (address _asset);
}

/**
 * @title IPrivacyPoolSimple
 * @notice Interface for the PrivacyPool native asset implementation
 */
interface IPrivacyPoolSimple is IPrivacyPool {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when sending less amount of native asset than required
   */
  error InsufficientValue();

  /**
   * @notice Thrown when failing to send native asset to an account
   */
  error FailedToSendETH();
}

/**
 * @title IPrivacyPoolComplex
 * @notice Interface for the PrivacyPool ERC20 implementation
 */
interface IPrivacyPoolComplex is IPrivacyPool {
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when sending sending any amount of native asset
   */
  error NativeAssetNotAccepted();
}
