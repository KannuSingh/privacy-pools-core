import { ethers } from "ethers";
import { generateMerkleProof } from "@privacy-pool-core/sdk";

async function main() {
  // Fetch script arguments
  const args = process.argv.slice(2);

  // Leaf we want to prove
  const leaf = BigInt(args[0]);
  // All leaves in tree
  const leaves = args.slice(1).map(BigInt);

  // Generate merkle proof using the SDK method
  const proof = generateMerkleProof(leaves, leaf);

  // Fix the issue with index being NaN for depth 0 (LeanIMT issue)
  proof.index = Object.is(proof.index, NaN) ? 0 : proof.index;

  // Convert proof to ABI-encoded bytes
  const abiCoder = new ethers.AbiCoder();
  const encodedProof = abiCoder.encode(
    ["uint256", "uint256", "uint256[]"],
    [proof.root, proof.index, proof.siblings],
  );

  // Write to stdout as hex string
  process.stdout.write(encodedProof);
}

main().catch(console.error);
