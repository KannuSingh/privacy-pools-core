import { generatePrivateKey } from "viem/accounts";
import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { LeanIMT, LeanIMTMerkleProof } from "@zk-kit/lean-imt";
import {
  ErrorCode,
  PrivacyPoolError,
} from "./exceptions/privacyPool.exception.js";
import { Commitment, Hash, Secret, Withdrawal } from "./types/index.js";
import { encodeAbiParameters, Hex, keccak256, numberToHex } from "viem";
import { SNARK_SCALAR_FIELD } from "./constants.js";

/**
 * Validates that a bigint value is not zero
 * @param value The value to check
 * @param name The name of the value for the error message
 * @throws {PrivacyPoolError} If the value is zero
 */
function validateNonZero(value: bigint, name: string) {
  if (value === BigInt(0)) {
    throw new PrivacyPoolError(
      ErrorCode.INVALID_VALUE,
      `Invalid input: '${name}' cannot be zero.`,
    );
  }
}

/**
 * Generates random nullifier and secret.
 *
 * @returns {{ nullifier: Secret, secret: Secret }} Randomly generated secrets.
 */
export function generateSecrets(): { nullifier: Secret; secret: Secret } {
  const nullifier = (BigInt(generatePrivateKey()) %
    SNARK_SCALAR_FIELD) as Secret;
  const secret = (BigInt(generatePrivateKey()) % SNARK_SCALAR_FIELD) as Secret;
  return { nullifier, secret };
}

/**
 * Computes a Poseidon hash for the given nullifier and secret.
 *
 * @param {Secret} nullifier - The nullifier to hash.
 * @param {Secret} secret - The secret to hash.
 * @returns {Hash} The Poseidon hash.
 */
export function hashPrecommitment(nullifier: Secret, secret: Secret): Hash {
  return poseidon([nullifier, secret]) as Hash;
}

/**
 * Generates a commitment using the given parameters.
 *
 * @param {bigint} value - The value associated with the commitment.
 * @param {bigint} label - The label used for the commitment.
 * @param {Secret} nullifier - The nullifier used in the precommitment.
 * @param {Secret} secret - The secret used in the precommitment.
 * @returns {Commitment} The generated commitment object.
 */
export function getCommitment(
  value: bigint,
  label: bigint,
  nullifier: Secret,
  secret: Secret,
): Commitment {
  validateNonZero(nullifier as bigint, "nullifier");
  validateNonZero(label, "label");
  validateNonZero(secret as bigint, "secret");

  const precommitment = {
    hash: hashPrecommitment(nullifier, secret),
    nullifier,
    secret,
  };

  const hash = poseidon([value, label, precommitment.hash]) as Hash;

  return {
    hash,
    nullifierHash: precommitment.hash,
    preimage: {
      value,
      label,
      precommitment,
    },
  };
}

/**
 * Generates a Merkle inclusion proof for a given leaf in a set of leaves.
 *
 * @param {bigint[]} leaves - Array of leaves for the Lean Incremental Merkle tree.
 * @param {bigint} leaf - The specific leaf to generate the inclusion proof for.
 * @returns {LeanIMTMerkleProof<bigint>} A lean incremental Merkle tree inclusion proof.
 * @throws {Error} If the leaf is not found in the leaves array.
 */
export function generateMerkleProof(
  leaves: bigint[],
  leaf: bigint,
): LeanIMTMerkleProof<bigint> {
  const tree = new LeanIMT<bigint>((a, b) => poseidon([a, b]));

  tree.insertMany(leaves);

  const leafIndex = tree.indexOf(leaf);

  // if leaf does not exist in tree, throw error
  if (leafIndex === -1) {
    throw new PrivacyPoolError(
      ErrorCode.MERKLE_ERROR,
      "Leaf not found in the leaves array.",
    );
  }

  return tree.generateProof(leafIndex);
}

export function bigintToHash(value: bigint): Hash {
  return `0x${value.toString(16).padStart(64, "0")}` as unknown as Hash;
}

export function bigintToHex(num: bigint | string | undefined): Hex {
  if (num === undefined) throw new Error("Undefined bigint value!");
  return `0x${BigInt(num).toString(16).padStart(64, "0")}`;
}

/**
 * Calculates the context hash for a withdrawal.
 */
export function calculateContext(withdrawal: Withdrawal, scope: Hash): string {
  const hash =
    BigInt(
      keccak256(
        encodeAbiParameters(
          [
            {
              name: "withdrawal",
              type: "tuple",
              components: [
                { name: "processooor", type: "address" },
                { name: "data", type: "bytes" },
              ],
            },
            { name: "scope", type: "uint256" },
          ],
          [
            {
              processooor: withdrawal.processooor,
              data: withdrawal.data,
            },
            scope,
          ],
        ),
      ),
    ) % SNARK_SCALAR_FIELD;
  return numberToHex(hash);
}
