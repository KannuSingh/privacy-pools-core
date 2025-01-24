import { Address } from "viem";
import { Groth16Proof, PublicSignals } from "snarkjs";
import { LeanIMTMerkleProof } from "@zk-kit/lean-imt";
import { Hash, Secret } from "./commitment.js";

/**
 * Represents a withdrawal request in the system.
 */
export interface Withdrawal {
  readonly procesooor: Address;
  readonly scope: Hash;
  readonly data: Uint8Array;
}

/**
 * Complete withdrawal payload including proof and public signals.
 */
export interface WithdrawalPayload {
  readonly proof: Groth16Proof;
  readonly publicSignals: PublicSignals;
  readonly withdrawal: Withdrawal;
}

/**
 * Input parameters required for withdrawal proof generation.
 */
export interface WithdrawalProofInput {
  readonly withdrawalAmount: bigint;
  readonly stateMerkleProof: LeanIMTMerkleProof<bigint>;
  readonly aspMerkleProof: LeanIMTMerkleProof<bigint>;
  readonly stateRoot: Hash;
  readonly aspRoot: Hash;
  readonly newSecret: Secret;
  readonly newNullifier: Secret;
}