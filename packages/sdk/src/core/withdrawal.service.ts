import * as snarkjs from "snarkjs";
import {
  encodeAbiParameters,
  hexToBigInt,
  keccak256,
  numberToHex,
} from "viem";
import { SNARK_SCALAR_FIELD } from "../constants.js";
import { ProofError } from "../errors/base.error.js";
import {
  CircuitName,
  CircuitsInterface,
} from "../interfaces/circuits.interface.js";
import { Commitment } from "../types/commitment.js";
import {
  Withdrawal,
  WithdrawalProof,
  WithdrawalProofInput,
} from "../types/withdrawal.js";

/**
 * Service responsible for handling withdrawal-related operations.
 */
export class WithdrawalService {
  constructor(private readonly circuits: CircuitsInterface) { }

  /**
   * Generates a withdrawal proof.
   *
   * @param commitment - Commitment to withdraw
   * @param input - Input parameters for the withdrawal
   * @param withdrawal - Withdrawal details
   * @returns Promise resolving to withdrawal payload
   * @throws {ProofError} If proof generation fails
   */
  public async proveWithdrawal(
    commitment: Commitment,
    input: WithdrawalProofInput,
  ): Promise<WithdrawalProof> {
    try {
      const inputSignals = this.prepareInputSignals(commitment, input);

      const wasm = await this.circuits.getWasm(CircuitName.Withdraw);
      const zkey = await this.circuits.getProvingKey(CircuitName.Withdraw);

      const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        inputSignals,
        wasm,
        zkey,
      );

      return {
        proof,
        publicSignals,
      };
    } catch (error) {
      throw ProofError.generationFailed({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  /**
   * Verifies a withdrawal proof.
   *
   * @param withdrawalPayload - The withdrawal payload to verify
   * @returns Promise resolving to boolean indicating proof validity
   * @throws {ProofError} If verification fails
   */
  public async verifyWithdrawal(
    withdrawalPayload: WithdrawalProof,
  ): Promise<boolean> {
    try {
      const vkeyBin = await this.circuits.getVerificationKey(
        CircuitName.Withdraw,
      );
      const vkey = JSON.parse(new TextDecoder("utf-8").decode(vkeyBin));
      return await snarkjs.groth16.verify(
        vkey,
        withdrawalPayload.publicSignals,
        withdrawalPayload.proof,
      );
    } catch (error) {
      throw ProofError.verificationFailed({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  /**
   * Prepares input signals for the withdrawal circuit.
   */
  private prepareInputSignals(
    commitment: Commitment,
    input: WithdrawalProofInput,
  ): Record<string, bigint | bigint[] | string> {
    return {
      // Public signals
      withdrawnValue: input.withdrawalAmount,
      stateRoot: input.stateRoot,
      stateTreeDepth: input.stateTreeDepth,
      ASPRoot: input.aspRoot,
      ASPTreeDepth: input.aspTreeDepth,
      context: input.context,

      // Private signals
      label: commitment.preimage.label,
      existingValue: commitment.preimage.value,
      existingNullifier: commitment.preimage.precommitment.nullifier,
      existingSecret: commitment.preimage.precommitment.secret,
      newNullifier: input.newNullifier,
      newSecret: input.newSecret,

      // Merkle Proofs
      stateSiblings: input.stateMerkleProof.siblings,
      stateIndex: BigInt(input.stateMerkleProof.index),
      ASPSiblings: input.aspMerkleProof.siblings,
      ASPIndex: BigInt(input.aspMerkleProof.index),
    };
  }
}
