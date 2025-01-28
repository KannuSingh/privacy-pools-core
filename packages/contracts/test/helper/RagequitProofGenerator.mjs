#!/usr/bin/env node

import { PrivacyPoolSDK, Circuits } from "@privacy-pool-core/sdk";
import { encodeAbiParameters } from "viem";

async function main() {
  // Get command line arguments
  const [value, label, nullifier, secret] = process.argv.slice(2).map(BigInt);

  // Initialize SDK with circuits
  const circuits = new Circuits();
  const privacyPoolSDK = new PrivacyPoolSDK(circuits);

  try {
    // Generate the commitment proof
    const { proof, publicSignals } = await privacyPoolSDK.proveCommitment(
      value,
      label,
      nullifier,
      secret,
    );

    // Format the proof to match the Solidity struct
    const ragequitProof = {
      _pA: [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])],
      _pB: [
        [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])],
        [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])],
      ],
      _pC: [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])],
      _pubSignals: [
        publicSignals[0], // commitment hash
        publicSignals[1], // precommitment hash
        publicSignals[2], // nullifier hash
        publicSignals[3], // value
        publicSignals[4], // label
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
            { name: "_pubSignals", type: "uint256[5]" },
          ],
        },
      ],
      [ragequitProof],
    );

    // Output the encoded proof directly to stdout
    process.stdout.write(encodedProof);
    process.exit(0);
  } catch (error) {
    console.error("Error generating proof:", error);
    process.exit(1);
  }
}

main().catch(console.error);
