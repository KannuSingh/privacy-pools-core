import { Address } from "viem";
import { Hash } from "./commitment.js";

/**
 * Represents a deposit event from a privacy pool
 */
export interface DepositEvent {
  depositor: Address;
  commitment: Hash;
  label: Hash;
  value: bigint;
  precommitment: Hash;
  blockNumber: bigint;
  transactionHash: Hash;
}

/**
 * Represents a withdrawal event from a privacy pool
 */
export interface WithdrawalEvent {
  withdrawn: bigint;
  spentNullifier: Hash;
  newCommitment: Hash;
  blockNumber: bigint;
  transactionHash: Hash;
}

/**
 * Configuration for a chain's data provider
 */
export interface ChainConfig {
  chainId: number;
  rpcUrl: string;
  privacyPoolAddress: Address;
  startBlock: bigint;
}

/**
 * Event filter options
 */
export interface EventFilterOptions {
  fromBlock?: bigint;
  toBlock?: bigint;
  depositor?: Address;
}

/**
 * Collection of pool events
 */
export interface PoolEvents {
  deposits: DepositEvent[];
  withdrawals: WithdrawalEvent[];
} 