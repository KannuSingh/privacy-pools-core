import { Hash, Secret } from "./commitment.js";
import { Address } from "viem";

export interface PoolAccount {
  label: Hash;
  deposit: AccountCommitment;
  children: AccountCommitment[];
}

export interface AccountCommitment {
  hash: Hash;
  value: bigint;
  label: Hash;
  nullifier: Secret;
  secret: Secret;
  blockNumber: bigint;
  timestamp: bigint;
  txHash: Hash;
}

export interface PrivacyPoolAccount {
  masterKeys: [Secret, Secret];
  poolAccounts: Map<bigint, PoolAccount[]>;
  creationTimestamp: bigint;
  lastUpdateTimestamp: bigint;
}

export interface PoolInfo {
  chainId: number;
  address: Address;
  scope: Hash;
  deploymentBlock: bigint;
}
