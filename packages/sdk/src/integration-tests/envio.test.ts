import { DataService } from "../core/data.service.js";
import { AccountService } from "../core/account.service.js";
import { ChainConfig, DepositEvent, WithdrawalEvent } from "../types/events.js";
import { Hash } from "../types/commitment.js";
import { PoolInfo } from "../types/account.js";

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

  const poolInfo: PoolInfo = {
    chainId: testnetConfig.chainId,
    address: testnetConfig.privacyPoolAddress,
    scope:8390609771286767778444554427378460518340407258832236147184474429413358473828n as Hash, // TODO: Replace with actual scope
    deploymentBlock: testnetConfig.startBlock,
  };

  console.log("Starting Envio integration test...");
  console.log("Configuration:", {
    chainId: testnetConfig.chainId,
    privacyPoolAddress: testnetConfig.privacyPoolAddress,
    startBlock: testnetConfig.startBlock,
  });

  // Initialize services
  const dataService = new DataService([testnetConfig]);
  const accountService = new AccountService(dataService);

  try {
    // Test deposit event fetching
    console.log("\nFetching deposit events...");
    const deposits = await dataService.getDeposits(testnetConfig.chainId, {
      fromBlock: testnetConfig.startBlock,
    });
    console.log(`Found ${deposits.length} deposits`);

    console.log(deposits);
    
    if (deposits.length > 0) {
      const firstDeposit = deposits[0] as DepositEvent;
      console.log("Sample deposit:", {
        blockNumber: firstDeposit.blockNumber.toString(),
        value: firstDeposit.value.toString(),
        transactionHash: firstDeposit.transactionHash,
      });
    }

    // Test withdrawal event fetching
    console.log("\nFetching withdrawal events...");
    const withdrawals = await dataService.getWithdrawals(testnetConfig.chainId, {
      fromBlock: testnetConfig.startBlock,
    });
    console.log(`Found ${withdrawals.length} withdrawals`);
    
    if (withdrawals.length > 0) {
      const firstWithdrawal = withdrawals[0] as WithdrawalEvent;
      console.log("Sample withdrawal:", {
        blockNumber: firstWithdrawal.blockNumber.toString(),
        withdrawn: firstWithdrawal.withdrawn.toString(),
        transactionHash: firstWithdrawal.transactionHash,
      });
    }

    // Test full account reconstruction
    console.log("\nTesting full account reconstruction...");
    await accountService.retrieveHistory([poolInfo]);

    // Check reconstructed accounts
    const spendable = accountService.getSpendableCommitments();
    const poolAccounts = spendable.get(poolInfo.scope);
    
    console.log("\nReconstruction results:");
    console.log(`Found ${poolAccounts?.length || 0} spendable commitments`);
    
    if (poolAccounts && poolAccounts.length > 0) {
      console.log("\nSpendable commitments:");
      poolAccounts.forEach((commitment, i) => {
        console.log(`\nCommitment ${i + 1}:`);
        console.log("Value:", commitment.value.toString());
        console.log("Label:", commitment.label);
        console.log("Hash:", commitment.hash);
      });
    }

  } catch (error) {
    console.error("\nError during integration test:", error);
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