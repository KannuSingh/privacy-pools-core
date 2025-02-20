import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { Hash, Secret } from "./types/index.js";
import { Hex } from "viem";
import { generatePrivateKey } from "viem/accounts";

export function genMasterKeys(seed?: Hex): [Secret, Secret] {
  let preimage = seed ? poseidon([BigInt(seed)]) : BigInt(generatePrivateKey());

  let masterKey1 = poseidon([preimage, BigInt(1)]) as Secret;
  let masterKey2 = poseidon([preimage, BigInt(2)]) as Secret;

  return [masterKey1, masterKey2];
}

/**
 * Computes a Poseidon hash for the given nullifier and secret.
 *
 * @param {Secret} nullifier - The nullifier to hash.
 * @param {Secret} secret - The secret to hash.
 * @returns {Hash} The Poseidon hash.
 */
export function getDepositSecrets(
  masterKey: [Secret, Secret],
  scope: Hash,
  index: bigint,
): { nullifier: Secret; secret: Secret } {
  let depositNullifier = poseidon([masterKey[0], scope, index]) as Secret;
  let depositSecret = poseidon([masterKey[1], scope, index]) as Secret;

  return { nullifier: depositNullifier, secret: depositSecret };
}

export function getWithdrawalSecrets(
  masterKey: [Secret, Secret],
  label: Hash,
  index: bigint,
): { nullifier: Secret; secret: Secret } {
  let withdrawalNullifier = poseidon([masterKey[0], label, index]) as Secret;
  let withdrawalSecret = poseidon([masterKey[1], label, index]) as Secret;

  return { nullifier: withdrawalNullifier, secret: withdrawalSecret };
}
