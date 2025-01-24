import { describe, it, expect } from "vitest";
import {
  generateSecrets,
  hashPrecommitment,
  getCommitment,
  generateMerkleProof,
} from "../../src/crypto.js";
import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { Secret } from "../../src/types/commitment.js";

describe("Crypto Utilities", () => {
  describe("generateSecrets", () => {
    it("generates two unique non-zero bigint secrets", () => {
      const { nullifier, secret } = generateSecrets();

      expect(nullifier).not.toBe(BigInt(0));
      expect(secret).not.toBe(BigInt(0));
      expect(nullifier).not.toEqual(secret);
    });
  });

  describe("hashPrecommitment", () => {
    it("computes Poseidon hash of nullifier and secret", () => {
      const nullifier = BigInt(123) as Secret;
      const secret = BigInt(456) as Secret;

      const hash = hashPrecommitment(nullifier, secret);
      const expectedHash = poseidon([nullifier, secret]);

      expect(hash).toEqual(expectedHash);
    });
  });

  describe("getCommitment", () => {
    it("creates a valid commitment", () => {
      const value = BigInt(1000);
      const label = BigInt(42);
      const { nullifier, secret } = generateSecrets();

      const commitment = getCommitment(value, label, nullifier, secret);

      expect(commitment.hash).toBeDefined();
      expect(commitment.nullifierHash).toBeDefined();
      expect(commitment.preimage.value).toBe(value);
      expect(commitment.preimage.label).toBe(label);
    });

    it("throws error for zero nullifier", () => {
      expect(() =>
        getCommitment(BigInt(1000), BigInt(42), BigInt(0) as Secret, BigInt(123) as Secret),
      ).toThrow("Invalid input: 'nullifier' cannot be zero.");
    });

    it("throws error for zero label", () => {
      expect(() =>
        getCommitment(BigInt(1000), BigInt(0), BigInt(123) as Secret, BigInt(456) as Secret),
      ).toThrow("Invalid input: 'label' cannot be zero.");
    });

    it("throws error for zero secret", () => {
      expect(() =>
        getCommitment(BigInt(1000), BigInt(42), BigInt(123) as Secret, BigInt(0) as Secret),
      ).toThrow("Invalid input: 'secret' cannot be zero.");
    });
  });

  describe("generateMerkleProof", () => {
    it("generates Merkle proof for existing leaf", () => {
      const leaves = [BigInt(1), BigInt(2), BigInt(3), BigInt(4)];

      const targetLeaf = BigInt(3);
      const proof = generateMerkleProof(leaves, targetLeaf);

      expect(proof).toHaveProperty("root");
      expect(proof).toHaveProperty("leaf", targetLeaf);
      expect(proof).toHaveProperty("index");
      expect(proof).toHaveProperty("siblings");
    });

    it("throws error for non-existent leaf", () => {
      const leaves = [BigInt(1), BigInt(2), BigInt(4)];

      expect(() => {
        generateMerkleProof(leaves, BigInt(3));
      }).toThrow("Leaf not found in the leaves array.");
    });
  });
});
