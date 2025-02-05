import { describe, it, expect } from "vitest";
import {
  generateSecrets,
  hashPrecommitment,
  getCommitment,
  generateMerkleProof,
  calculateContext,
} from "../../src/crypto.js";
import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { Hash, Secret } from "../../src/types/commitment.js";
import { getAddress, Hex, keccak256 } from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { SNARK_SCALAR_FIELD } from "../../src/constants.js";
import { Withdrawal } from "../../src/index.js";

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
        getCommitment(
          BigInt(1000),
          BigInt(42),
          BigInt(0) as Secret,
          BigInt(123) as Secret,
        ),
      ).toThrow("Invalid input: 'nullifier' cannot be zero.");
    });

    it("throws error for zero label", () => {
      expect(() =>
        getCommitment(
          BigInt(1000),
          BigInt(0),
          BigInt(123) as Secret,
          BigInt(456) as Secret,
        ),
      ).toThrow("Invalid input: 'label' cannot be zero.");
    });

    it("throws error for zero secret", () => {
      expect(() =>
        getCommitment(
          BigInt(1000),
          BigInt(42),
          BigInt(123) as Secret,
          BigInt(0) as Secret,
        ),
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

  describe("calculateContext", () => {
    it("calculates the context correctly", () => {

      const withdrawal = {
        processooor: getAddress("0xa513E6E4b8f2a923D98304ec87F64353C4D5C853"),
        scope: BigInt("0x0555c5fdc167f1f1519c1b21a690de24d9be5ff0bde19447a5f28958d9256e50") as Hash,
        data: "0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266000000000000000000000000000000000000000000000000000000000000c350" as Hex,
      };
      expect(calculateContext(withdrawal)).toStrictEqual("0x21a25ae329bcce0ede103b5f8279c83b61b647dfd2bc8cfac3836456011cf3b6");
    })

    it("calculates returns a scalar field bounded value", () => {
      const withdrawal: Withdrawal = {
        processooor: privateKeyToAccount(generatePrivateKey()).address,
        scope: BigInt(keccak256(generatePrivateKey())) as Hash,
        data: keccak256(generatePrivateKey()),
      };
      const result = calculateContext(withdrawal);
      expect(BigInt(result) % SNARK_SCALAR_FIELD).toStrictEqual(BigInt(result));
    })
  })

});
