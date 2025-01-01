// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from '../contracts/lib/ProofLib.sol';
import {IERC20} from '@oz/interfaces/IERC20.sol';
import {IState} from 'interfaces/IState.sol';

interface IPrivacyPool is IState {
  struct Withdrawal {
    address procesooor;
    bytes data;
  }

  event Deposited();
  event PoolDied();
  event Ragequit();
  event Withdrawn();

  error InvalidCommitment();
  error InvalidNullifier();
  error InvalidProcesooor();
  error ScopeMismatch();
  error ContextMismatch();
  error UnknownStateRoot();
  error OutdatedASPRoot();
  error OnlyOriginalDepositor();
  error InvalidWithdrawalAmount();
  error ZeroAddress();

  function deposit(
    address _depositor,
    uint256 _value,
    uint256 _precommitmentHash
  ) external payable returns (uint256 _commitment);

  function withdraw(Withdrawal memory _w, ProofLib.Proof memory _p) external;

  function ragequit(uint256 _value, uint256 _label, uint256 _nullifier, uint256 _secret) external;

  function windDown() external;

  function SCOPE() external view returns (uint256);

  function ASSET() external view returns (IERC20);
}
