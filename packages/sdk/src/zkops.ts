import * as snarkjs from "snarkjs";
import { CircuitSignals, Groth16Proof, PublicSignals } from "snarkjs";
import {
  CircuitName,
  CircuitsInterface,
} from "./circuits/circuits.interface.js";

/**
 * Class representing zero-knowledge operations.
 */
export class ZkOps {
  /**
   * The circuits interface providing access to circuit-related resources.
   * @type {CircuitsInterface}
   */
  circuits: CircuitsInterface;

  /**
   * Constructs a new instance of the ZkOps class.
   * @param {CircuitsInterface} circuits - An interface for accessing circuit-related resources.
   */
  constructor(circuits: CircuitsInterface) {
    this.circuits = circuits;
  }

  /**
   * Generates a zero-knowledge proof for a commitment circuit.
   *
   * @param {CircuitSignals} signals - The input signals for the circuit (e.g., commitment signals).
   * @returns {Promise<{ proof: Groth16Proof; publicSignals: PublicSignals }>}
   *          A promise that resolves to an object containing the proof and public signals.
   * @async
   */
  async proveCommitment(
    signals: CircuitSignals, // TODO: type commitment signals
  ): Promise<{ proof: Groth16Proof; publicSignals: PublicSignals }> {
    const wasm = await this.circuits.getWasm(CircuitName.Commitment);
    const zkey = await this.circuits.getProvingKey(CircuitName.Commitment);
    return await snarkjs.groth16.fullProve(signals, wasm, zkey);
  }
}
