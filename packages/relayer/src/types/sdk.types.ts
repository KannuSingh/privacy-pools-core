import {
  Address,
  Withdrawal,
  WithdrawalProof,
} from "@defi-wonderland/privacy-pool-core-sdk";
import { WithdrawalPayload } from "../interfaces/relayer/request.js";

export interface SdkProviderInterface {
  verifyWithdrawal(withdrawalPayload: WithdrawalProof): Promise<boolean>;
  broadcastWithdrawal(
    withdrawalPayload: WithdrawalPayload,
  ): Promise<{ hash: string }>;
  calculateContext(withdrawal: Withdrawal): string;
  scopeData(
    scope: bigint,
  ): Promise<{ poolAddress: Address; assetAddress: Address }>;
}
