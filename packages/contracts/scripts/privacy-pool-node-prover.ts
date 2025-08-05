import { parseEther } from "viem";
import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { LeanIMT } from "@zk-kit/lean-imt";
import * as snarkjs from "snarkjs";
import * as fs from "fs";
import { join } from "path";

// ============ TYPES ============
interface Commitment {
    value: bigint;
    label: bigint;
    nullifier: bigint;
    secret: bigint;
}

interface WithdrawalProofData {
    proof: {
        pi_a: string[];
        pi_b: string[][];
        pi_c: string[];
    };
    publicSignals: string[];
}

interface CircuitPaths {
    wasmPath: string;
    zkeyPath: string;
    vkeyPath: string;
}

// ============ CONFIGURATION ============
const CIRCUITS_BASE_PATH = "/Users/karandeepsingh/Desktop/ANGC/privacy-pools-core/packages/circuits";
const MAX_TREE_DEPTH = 32;

// ============ UTILITY FUNCTIONS ============
function randomBigInt(): bigint {
    return BigInt(Math.floor(Math.random() * Number.MAX_SAFE_INTEGER));
}

function padSiblings(siblings: bigint[], targetDepth: number): bigint[] {
    const paddedSiblings = [...siblings];
    while (paddedSiblings.length < targetDepth) {
        paddedSiblings.push(BigInt(0));
    }
    return paddedSiblings;
}

function hashCommitment(input: Commitment): [bigint, bigint] {
    const precommitment = poseidon([input.nullifier, input.secret]);
    const nullifierHash = poseidon([input.nullifier]);
    const commitmentHash = poseidon([input.value, input.label, precommitment]);
    return [commitmentHash, nullifierHash];
}

// ============ CIRCUIT FILE MANAGEMENT ============
function getCircuitPaths(): CircuitPaths {
    return {
        wasmPath: join(CIRCUITS_BASE_PATH, "build/withdraw/withdraw_js/withdraw.wasm"),
        zkeyPath: join(CIRCUITS_BASE_PATH, "trusted-setup/final-keys/withdraw.zkey"),
        vkeyPath: join(CIRCUITS_BASE_PATH, "trusted-setup/final-keys/withdraw.vkey"),
    };
}

function verifyCircuitFiles(): boolean {
    const paths = getCircuitPaths();
    const missing = Object.entries(paths).filter(([, path]) => !fs.existsSync(path));

    if (missing.length > 0) {
        console.error("❌ Missing circuit files:");
        missing.forEach(([name, path]) => console.error(`   ${name}: ${path}`));
        return false;
    }

    console.log("✅ All circuit files found");
    return true;
}

// ============ PRIVACY POOL PROOF GENERATOR ============
export class PrivacyPoolNodeProver {
    private circuitPaths: CircuitPaths;
    private hash: (a: bigint, b: bigint) => bigint;

    constructor() {
        this.circuitPaths = getCircuitPaths();
        this.hash = (a: bigint, b: bigint) => poseidon([a, b]);

        if (!verifyCircuitFiles()) {
            throw new Error("Circuit files not found. Run circuit setup first.");
        }
    }

    /**
     * Generate a real withdrawal proof using direct snarkjs calls
     */
    async generateWithdrawalProof(args: {
        existingCommitmentHash: bigint;
        withdrawalValue: bigint;
        context: bigint;
        label: bigint;
        existingValue: bigint;
        existingNullifier: bigint;
        existingSecret: bigint;
        newNullifier: bigint;
        newSecret: bigint;
        stateTreeCommitments: bigint[];
        aspTreeLabels: bigint[];
    }): Promise<WithdrawalProofData> {
        console.log("🔧 Generating withdrawal proof...");
        const {
            existingCommitmentHash,
            withdrawalValue,
            context,
            label,
            existingValue,
            existingNullifier,
            existingSecret,
            newNullifier,
            newSecret,
            stateTreeCommitments,
            aspTreeLabels,
        } = args;

        // Build state tree
        const stateTree = new LeanIMT(this.hash);
        stateTreeCommitments.forEach((commitment) => stateTree.insert(commitment));
        // Build ASP tree
        const aspTree = new LeanIMT(this.hash);
        aspTreeLabels.forEach((label) => aspTree.insert(label));
        // Find indices
        // const [existingCommitmentHash] = hashCommitment(existingCommitment);
        const stateIndex = stateTreeCommitments.indexOf(existingCommitmentHash);
        const aspIndex = aspTreeLabels.indexOf(label);

        if (stateIndex === -1) {
            throw new Error("Existing commitment not found in state tree");
        }
        if (aspIndex === -1) {
            throw new Error("Commitment label not found in ASP tree");
        }

        // Generate proofs
        const stateProof = stateTree.generateProof(stateIndex);
        const aspProof = aspTree.generateProof(aspIndex);

        // Calculate new commitment value
        const newValue = existingValue - withdrawalValue;

        // Prepare circuit inputs exactly as circuit tests do
        const circuitInputs = {
            withdrawnValue: withdrawalValue.toString(),
            stateRoot: stateProof.root.toString(),
            stateTreeDepth: stateTree.depth.toString(),
            ASPRoot: aspProof.root.toString(),
            ASPTreeDepth: aspTree.depth.toString(),
            context: context.toString(),
            label: label.toString(),
            existingValue: existingValue.toString(),
            existingNullifier: existingNullifier.toString(),
            existingSecret: existingSecret.toString(),
            newNullifier: newNullifier.toString(),
            newSecret: newSecret.toString(),
            stateSiblings: padSiblings(stateProof.siblings, MAX_TREE_DEPTH).map((s) => s.toString()),
            stateIndex: stateIndex, // or stateProof.index.toString(),
            ASPSiblings: padSiblings(aspProof.siblings, MAX_TREE_DEPTH).map((s) => s.toString()),
            ASPIndex: aspIndex, // or aspProof.index.toString(),
        };

        // Generate proof using direct snarkjs
        const startTime = Date.now();
        console.log("   🚀 Generating proof with snarkjs...");

        const { proof, publicSignals } = await snarkjs.groth16.fullProve(circuitInputs, this.circuitPaths.wasmPath, this.circuitPaths.zkeyPath);

        const endTime = Date.now();
        console.log(`   ✅ Proof generated in ${endTime - startTime}ms`);
        const isValid = await this.verifyWithdrawalProof({ proof, publicSignals });

        if (isValid) {
            console.log("\n🎉 SUCCESS: Real Privacy Pool withdrawal proof generated and verified!");
            console.log("🎯 Ready for SimplePrivacyPool + paymaster integration");
            return { proof, publicSignals };
        } else {
            throw new Error("\n❌ FAILED: Proof verification failed");
        }
    }

    /**
     * Verify a withdrawal proof
     */
    async verifyWithdrawalProof(proofData: WithdrawalProofData): Promise<boolean> {
        console.log("🔍 Verifying withdrawal proof...");

        const vkey = JSON.parse(fs.readFileSync(this.circuitPaths.vkeyPath, "utf8"));
        const isValid = await snarkjs.groth16.verify(vkey, proofData.publicSignals, proofData.proof as any);

        console.log(`   ${isValid ? "✅ Valid" : "❌ Invalid"} proof`);
        return isValid;
    }

    /**
     * Create a test scenario with deposits and withdrawals
     */
    createTestScenario() {
        console.log("🧪 Creating test scenario...");

        // Create initial deposits
        const deposit1: Commitment = {
            value: parseEther("5"),
            label: randomBigInt(),
            nullifier: randomBigInt(),
            secret: randomBigInt(),
        };

        const deposit2: Commitment = {
            value: parseEther("3"),
            label: randomBigInt(),
            nullifier: randomBigInt(),
            secret: randomBigInt(),
        };

        // Hash commitments
        const [deposit1Hash] = hashCommitment(deposit1);
        const [deposit2Hash] = hashCommitment(deposit2);

        // Create tree data
        const stateTreeCommitments = [deposit1Hash, deposit2Hash];

        const aspTreeLabels = [deposit1.label, deposit2.label];

        console.log("   ✅ Test scenario created");
        console.log(`   Deposits: ${stateTreeCommitments.length} state commitments, ${aspTreeLabels.length} ASP labels`);

        return {
            deposits: [deposit1, deposit2],
            stateTreeCommitments,
            aspTreeLabels,
        };
    }
}

// ============ EXAMPLE USAGE ============
async function demonstrateRealProofGeneration() {
    console.log("🚀 Privacy Pool Node.js Proof Generation Demo\n");

    try {
        // Initialize prover
        const prover = new PrivacyPoolNodeProver();
        console.log("✅ Prover initialized\n");

        // Create test scenario
        const scenario = prover.createTestScenario();
        const [deposit1] = scenario.deposits;

        // Generate withdrawal proof
        console.log("📝 Withdrawing 1 ETH from first deposit...\n");
        const [depositCommitmentHash] = hashCommitment(deposit1);
        const withdrawalProof = await prover.generateWithdrawalProof({
            existingCommitmentHash: depositCommitmentHash,
            withdrawalValue: parseEther("1"), // withdraw 1 ETH
            context: BigInt(1), // random context
            label: deposit1.label,
            existingValue: deposit1.value,
            existingNullifier: deposit1.nullifier,
            existingSecret: deposit1.secret,
            newNullifier: randomBigInt(), // new nullifier
            newSecret: randomBigInt(), // new secret
            stateTreeCommitments: scenario.stateTreeCommitments,
            aspTreeLabels: scenario.aspTreeLabels,
        });

        console.log("\n📊 Proof Generated:");
        console.log(`   Public signals: ${withdrawalProof.publicSignals.length}`);
        console.log(`   Proof pi_a: [${withdrawalProof.proof.pi_a[0].slice(0, 20)}..., ...]`);
        console.log(`   Proof structure complete: ${!!withdrawalProof.proof.pi_c}`);

        // Verify the proof
        // console.log("\n🔍 Verifying proof...");
        // const isValid = await prover.verifyWithdrawalProof(withdrawalProof);

        // if (isValid) {
        //     console.log("\n🎉 SUCCESS: Real Privacy Pool withdrawal proof generated and verified!");
        //     console.log("🎯 Ready for SimplePrivacyPool + paymaster integration");
        //     return withdrawalProof;
        // } else {
        //     console.log("\n❌ FAILED: Proof verification failed");
        //     return null;
        // }
    } catch (error) {
        console.error("\n💥 Demo failed:", error instanceof Error ? error.message : String(error));
    }
}

// ============ MAIN ============
if (require.main === module) {
    demonstrateRealProofGeneration().catch(console.error);
}

export { demonstrateRealProofGeneration };