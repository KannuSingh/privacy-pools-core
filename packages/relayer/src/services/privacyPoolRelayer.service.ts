import { WithdrawalPayload } from "@privacy-pool-core/sdk";
import { PROVIDER_URL, SIGNER_PRIVATE_KEY } from "../config.js";
import { RelayerError, ZkError } from "../exceptions/base.exception.js";
import { RelayerResponse } from "../interfaces/relayer/request.js";
import { db, SdkProvider } from "../providers/index.js";
import { RelayerDatabase } from "../types/db.types.js";

export class PrivacyPoolRelayer {
  private db: RelayerDatabase;
  private sdkService: SdkProvider;
  private readonly rpcUrl: string = PROVIDER_URL;
  private readonly privateKey: string = SIGNER_PRIVATE_KEY;

  constructor() {
    // Initialize database, provider, wallet, contract...
    this.db = db;
    this.sdkService = new SdkProvider();
  }

  async handleRequest(req: WithdrawalPayload): Promise<RelayerResponse> {
    const requestId = crypto.randomUUID();
    const timestamp = Date.now();

    try {
      // Store initial request
      this.db.createNewRequest(requestId, timestamp, req);

      // Verify commitment proof
      const isValidWithdrawal = await this.verifyProof(req.proof);
      if (!isValidWithdrawal) {
        throw ZkError.invalidProof();
      }

      const response = await this.broadcastWithdrawal(req);

      // Update database
      await this.db.updateBroadcastedRequest(requestId, response.hash);

      // Return success response
      return {
        success: true,
        txHash: response.hash,
        timestamp,
        requestId,
      };
    } catch (error) {
      let message: string;
      if (error instanceof RelayerError) {
        message = error.message;
      } else {
        message = JSON.stringify(error);
      }

      // Update database with error
      await this.db.updateFailedRequest(requestId, message);
      // Return error response
      return {
        success: false,
        error: message,
        timestamp,
        requestId,
      };
    }
  }

  // Helper methods
  private async verifyProof(
    proof: WithdrawalPayload["proof"],
  ): Promise<boolean> {
    return this.sdkService.verifyWithdrawal(proof);
  }

  private async broadcastWithdrawal(withdrawal: WithdrawalPayload) {
    return this.sdkService.broadcastWithdrawal(withdrawal, {
      privateKey: this.privateKey,
      rpcUrl: this.rpcUrl,
    });
  }
}
