#!/usr/bin/env node

import { ethers } from "ethers";
import {
  PrivacyPoolSDK,
  Circuits,
  getCommitment,
} from "@privacy-pool-core/sdk";
import { encodeAbiParameters } from "viem";

function padSiblings(siblings, treeDepth) {
  const paddedSiblings = [...siblings];
  while (paddedSiblings.length < treeDepth) {
    paddedSiblings.push(0n);
  }
  return paddedSiblings;
}

async function main() {
  const [
    existingValue,
    label,
    existingNullifier,
    existingSecret,
    newNullifier,
    newSecret,
    withdrawnValue,
    context,
    stateMerkleProofHex,
    stateTreeDepth,
    aspMerkleProofHex,
    aspTreeDepth,
  ] = process.argv.slice(2);

  const circuits = new Circuits();
  const sdk = new PrivacyPoolSDK(circuits);

  // Decode the Merkle proofs
  const abiCoder = new ethers.AbiCoder();
  const stateMerkleProof = abiCoder.decode(
    ["uint256", "uint256", "uint256[]"],
    stateMerkleProofHex,
  );
  const aspMerkleProof = abiCoder.decode(
    ["uint256", "uint256", "uint256[]"],
    aspMerkleProofHex,
  );

  const commitment = getCommitment(
    existingValue,
    label,
    existingNullifier,
    existingSecret,
  );

  // Pad siblings arrays to required length
  const paddedStateSiblings = padSiblings(stateMerkleProof[2], 32);
  const paddedAspSiblings = padSiblings(aspMerkleProof[2], 32);

  // Generate withdrawal proof
  const { proof, publicSignals } = await sdk.proveWithdrawal(commitment, {
    context,
    withdrawalAmount: withdrawnValue,
    stateMerkleProof: {
      root: stateMerkleProof[0],
      leaf: commitment.hash,
      index: stateMerkleProof[1],
      siblings: paddedStateSiblings,
    },
    aspMerkleProof: {
      root: aspMerkleProof[0],
      leaf: commitment.hash,
      index: aspMerkleProof[1],
      siblings: paddedAspSiblings,
    },
    stateRoot: stateMerkleProof[0],
    stateTreeDepth: parseInt(stateTreeDepth),
    aspRoot: aspMerkleProof[0],
    aspTreeDepth: parseInt(aspTreeDepth),
    newSecret,
    newNullifier,
  });

  // Format the proof to match the Solidity struct
  const withdrawalProof = {
    _pA: [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])],
    _pB: [
      [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])],
      [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])],
    ],
    _pC: [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])],
    _pubSignals: [
      publicSignals[0], // new commitment hash
      publicSignals[1], // existing nullifier hash
      publicSignals[2], // withdrawn value
      publicSignals[3], // state root
      publicSignals[4], // state depth
      publicSignals[5], // asp root
      publicSignals[6], // asp depth
      publicSignals[7], // context
    ].map((x) => BigInt(x)),
  };

  // ABI encode the proof
  const encodedProof = encodeAbiParameters(
    [
      {
        type: "tuple",
        components: [
          { name: "_pA", type: "uint256[2]" },
          { name: "_pB", type: "uint256[2][2]" },
          { name: "_pC", type: "uint256[2]" },
          { name: "_pubSignals", type: "uint256[8]" },
        ],
      },
    ],
    [withdrawalProof],
  );

  // Write to stdout as hex string
  process.stdout.write(encodedProof);
  process.exit(0);
}

main().catch(console.error);
