import { createPublicClient, http, Hex } from 'viem';
import { mainnet } from 'viem/chains';
import * as fs from 'fs';
import * as path from 'path';

const ENTRYPOINT_ADDRESS = '0x6818809EefCe719E480a7526D76bD3e561526b46';
const BATCH_SIZE = 100; 

const entryPointAbi = [
  {
    inputs: [{ internalType: 'uint256', name: 'precommitment', type: 'uint256' }],
    name: 'usedPrecommitments',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

type UsedPrecommitmentCall = {
  address: Hex;
  abi: typeof entryPointAbi;
  functionName: 'usedPrecommitments';
  args: readonly [bigint];
};

async function main() {
  const publicClient = createPublicClient({
    chain: mainnet,
    transport: http(),
  });

  const precommitmentsPath = path.join(__dirname, '../utils/precommitments.txt');
  const precommitmentsContent = fs.readFileSync(precommitmentsPath, 'utf-8');
  const precommitments = precommitmentsContent.split('\n').filter(Boolean);

  console.log(`Checking ${precommitments.length} precommitments...`);

  let successfullyUsedCount = 0;
  let foundUnusedCount = 0;
  let individualErrorCount = 0;
  let batchErrorCount = 0;
  let precommitmentsInFailedBatches = 0;

  for (let i = 0; i < precommitments.length; i += BATCH_SIZE) {
    const batch = precommitments.slice(i, i + BATCH_SIZE);
    const calls: readonly UsedPrecommitmentCall[] = batch.map((precommitment) => ({
      address: ENTRYPOINT_ADDRESS as Hex,
      abi: entryPointAbi,
      functionName: 'usedPrecommitments',
      args: [BigInt(precommitment)],
    }));

    try {
      const results = await publicClient.multicall({ contracts: calls as any });

      results.forEach((result: { status: string; result?: unknown, error?: Error }, index: number) => {
        const precommitment = batch[index];
        if (result.status === 'success') {
          if (result.result === true) {
            successfullyUsedCount++;
          } else {
            foundUnusedCount++;
            console.warn(`Precommitment ${precommitment}: IS NOT USED (false). Expected true.`);
          }
        } else {
          individualErrorCount++;
          console.error(`Error checking precommitment ${precommitment}: ${result.error}`);
        }
      });
    } catch (error) {
      batchErrorCount++;
      precommitmentsInFailedBatches += batch.length;
      console.error(`Error in multicall for batch starting at index ${i} (affecting ${batch.length} precommitments):`, error);
    }
  }

  console.log('\n--- Verification Summary ---');
  console.log(`Total Precommitments Checked: ${precommitments.length}`);
  console.log(`Successfully Verified as Used (true): ${successfullyUsedCount}`);
  console.log(`Found as Unused (false): ${foundUnusedCount}`);
  console.log(`Individual Errors (within successful batches): ${individualErrorCount}`);
  console.log(`Full Batch Errors: ${batchErrorCount}`);
  console.log(`Precommitments in Failed Batches: ${precommitmentsInFailedBatches}`);
  console.log('Finished checking precommitments.');
}

main().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
