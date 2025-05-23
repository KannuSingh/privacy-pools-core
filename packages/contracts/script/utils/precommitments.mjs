import * as fs from "fs";
import { fileURLToPath } from "url";
import { dirname, resolve } from "path";
import { encodeAbiParameters } from "viem";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const precommitments = fs
  .readFileSync(resolve(__dirname, "precommitments.txt"), "utf8")
  .split("\n")
  .filter((line) => line.trim() !== "")
  .map((line) => BigInt(line));


const encodedPrecommitments = encodeAbiParameters([{ type: "uint256[]" }], [precommitments]);

process.stdout.write(encodedPrecommitments);
