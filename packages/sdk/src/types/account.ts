import { Hash, Secret } from "./commitment.js";
import { Address } from "viem";

export interface PoolAccount {
  label: Hash;
  deposit: Commitment;
  children: Commitment[];
}

export interface Commitment {
  hash: Hash;
  value: bigint;
  label: Hash;
  nullifier: Secret;
  secret: Secret;
  blockNumber: bigint;
  txHash: Hash;
}

export interface PrivacyPoolAccount {
  mnemonic: string;
  masterKeys: [Secret, Secret];
  poolAccounts: Map<bigint, PoolAccount[]>;
}

export interface PoolInfo {
  chainId: number;
  address: Address;
  scope: Hash;
  deploymentBlock: bigint;
}
