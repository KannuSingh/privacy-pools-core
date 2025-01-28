import { ethers } from "ethers";
import { generateMerkleProof } from "@privacy-pool-core/sdk";

async function main() {
  const args = process.argv.slice(2);
  const leaf = BigInt(args[0]);
  const leaves = args.slice(1).map(BigInt);

  const proof = generateMerkleProof(leaves, leaf);

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
