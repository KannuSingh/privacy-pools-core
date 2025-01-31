import { WithdrawalPayload } from "@privacy-pool-core/sdk";

export interface RelayerDatabase {
  initialized: boolean;
  createNewRequest(
    requestId: string,
    timestamp: number,
    req: WithdrawalPayload,
  ): Promise<void>;
  updateBroadcastedRequest(requestId: string, txHash: string): Promise<void>;
  updateFailedRequest(requestId: string, errorMessage: string): Promise<void>;
}
