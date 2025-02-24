import { DataService } from "../core/data.service.js";
import { ChainConfig, DepositEvent, WithdrawalEvent, RagequitEvent } from "../types/events.js";

async function main() {
    // These values will be provided:
    // - chainId of the testnet
    // - contract address of the deployed privacy pool
    // - deployment block
    // - hypersync endpoint
    const ENVIO_TOKEN = process.env.ENVIO_TOKEN;
    if (!ENVIO_TOKEN) {
        throw new Error("ENVIO_TOKEN environment variable is required");
    }

    const testnetConfig: ChainConfig = {
        chainId: 11155111,
        rpcUrl: "https://1rpc.io/sepolia",
        privacyPoolAddress: "0x2A4Ba229D7EA7eeBF847df17778a5C5C78b3efF6",
        startBlock: 7705830n,
        envioToken: ENVIO_TOKEN,
    };

    console.log("Starting Envio event fetching test...");
    console.log("Configuration:", {
        chainId: testnetConfig.chainId,
        privacyPoolAddress: testnetConfig.privacyPoolAddress,
        startBlock: testnetConfig.startBlock,
    });

    // Initialize service
    const dataService = new DataService([testnetConfig]);

    try {
        // Test deposit event fetching
        console.log("\nFetching deposit events...");
        const deposits = await dataService.getDeposits(testnetConfig.chainId, {
            fromBlock: testnetConfig.startBlock,
        });
        console.log(`Found ${deposits.length} deposits`);

        if (deposits.length > 0) {
            console.log("\nDeposit events:");
            deposits.forEach((deposit, i) => {
                console.log(`\nDeposit ${i + 1}:`, {
                    blockNumber: deposit.blockNumber.toString(),
                    depositor: deposit.depositor,
                    value: deposit.value.toString(),
                    commitment: deposit.commitment,
                    label: deposit.label,
                    transactionHash: deposit.transactionHash,
                });
            });
        }

        // Test withdrawal event fetching
        console.log("\nFetching withdrawal events...");
        const withdrawals = await dataService.getWithdrawals(testnetConfig.chainId, {
            fromBlock: testnetConfig.startBlock,
        });
        console.log(`Found ${withdrawals.length} withdrawals`);

        if (withdrawals.length > 0) {
            console.log("\nWithdrawal events:");
            withdrawals.forEach((withdrawal, i) => {
                console.log(`\nWithdrawal ${i + 1}:`, {
                    blockNumber: withdrawal.blockNumber.toString(),
                    withdrawn: withdrawal.withdrawn.toString(),
                    spentNullifier: withdrawal.spentNullifier,
                    newCommitment: withdrawal.newCommitment,
                    transactionHash: withdrawal.transactionHash,
                });
            });
        }

        // Test ragequit event fetching
        console.log("\nFetching ragequit events...");
        const ragequits = await dataService.getRagequits(testnetConfig.chainId, {
            fromBlock: testnetConfig.startBlock,
        });
        console.log(`Found ${ragequits.length} ragequits`);

        if (ragequits.length > 0) {
            console.log("\nRagequit events:");
            ragequits.forEach((ragequit, i) => {
                console.log(`\nRagequit ${i + 1}:`, {
                    blockNumber: ragequit.blockNumber.toString(),
                    ragequitter: ragequit.ragequitter,
                    value: ragequit.value.toString(),
                    commitment: ragequit.commitment,
                    label: ragequit.label,
                    transactionHash: ragequit.transactionHash,
                });
            });
        }

    } catch (error) {
        console.error("\nError during event fetching test:", error);
        throw error;
    }
}

// Only run if called directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("Integration test failed:", error);
            process.exit(1);
        });
} 