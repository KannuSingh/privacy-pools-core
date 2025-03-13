/**
 * Handles withdrawal requests within the Privacy Pool relayer.
 */
import { getAddress } from "viem";
import {
  getEntrypointAddress,
  getFeeReceiverAddress,
  getAssetConfig
} from "../config/index.js";
import {
  RelayerError,
  WithdrawalValidationError,
  ZkError,
} from "../exceptions/base.exception.js";
import {
  RelayerResponse,
  WithdrawalPayload,
} from "../interfaces/relayer/request.js";
import { db, SdkProvider } from "../providers/index.js";
import { RelayerDatabase } from "../types/db.types.js";
import { decodeWithdrawalData, parseSignals } from "../utils.js";
import { SdkProviderInterface } from "../types/sdk.types.js";

/**
 * Class representing the Privacy Pool Relayer, responsible for processing withdrawal requests.
 */
export class PrivacyPoolRelayer {
  /** Database instance for storing and updating request states. */
  protected db: RelayerDatabase;
  /** SDK provider for handling blockchain interactions. */
  protected sdkProvider: SdkProviderInterface;

  /**
   * Initializes a new instance of the Privacy Pool Relayer.
   */
  constructor() {
    this.db = db;
    this.sdkProvider = new SdkProvider();
  }

  /**
   * Handles a withdrawal request.
   *
   * @param {WithdrawalPayload} req - The withdrawal request payload.
   * @param {number} chainId - The chain ID to process the request on.
   * @returns {Promise<RelayerResponse>} - A promise resolving to the relayer response.
   */
  async handleRequest(req: WithdrawalPayload, chainId: number): Promise<RelayerResponse> {
    const requestId = crypto.randomUUID();
    const timestamp = Date.now();

    try {
      await this.db.createNewRequest(requestId, timestamp, req);
      await this.validateWithdrawal(req, chainId);

      const isValidWithdrawalProof = await this.verifyProof(req.proof);
      if (!isValidWithdrawalProof) {
        throw ZkError.invalidProof();
      }

      const response = await this.broadcastWithdrawal(req, chainId);
      await this.db.updateBroadcastedRequest(requestId, response.hash);

      return {
        success: true,
        txHash: response.hash,
        timestamp,
        requestId,
      };
    } catch (error) {
      const message: string =
        error instanceof RelayerError ? error.message : JSON.stringify(error);
      await this.db.updateFailedRequest(requestId, message);
      return {
        success: false,
        error: message,
        timestamp,
        requestId,
      };
    }
  }

  /**
   * Verifies a withdrawal proof.
   *
   * @param {WithdrawalPayload["proof"]} proof - The proof to be verified.
   * @returns {Promise<boolean>} - A promise resolving to a boolean indicating verification success.
   */
  protected async verifyProof(
    proof: WithdrawalPayload["proof"],
  ): Promise<boolean> {
    return this.sdkProvider.verifyWithdrawal(proof);
  }

  /**
   * Broadcasts a withdrawal transaction.
   *
   * @param {WithdrawalPayload} withdrawal - The withdrawal payload.
   * @param {number} chainId - The chain ID to broadcast on.
   * @returns {Promise<{ hash: string }>} - A promise resolving to the transaction hash.
   */
  protected async broadcastWithdrawal(
    withdrawal: WithdrawalPayload,
    chainId: number,
  ): Promise<{ hash: string }> {
    return this.sdkProvider.broadcastWithdrawal(withdrawal, chainId);
  }

  /**
   * Validates a withdrawal request against relayer rules.
   *
   * @param {WithdrawalPayload} wp - The withdrawal payload.
   * @param {number} chainId - The chain ID to validate against.
   * @throws {WithdrawalValidationError} - If validation fails.
   * @throws {ValidationError} - If public signals are malformed.
   */
  protected async validateWithdrawal(wp: WithdrawalPayload, chainId: number) {
    const entrypointAddress = getEntrypointAddress(chainId);
    const feeReceiverAddress = getFeeReceiverAddress(chainId);
    
    const { feeRecipient, relayFeeBPS } = decodeWithdrawalData(
      wp.withdrawal.data,
    );
    const proofSignals = parseSignals(wp.proof.publicSignals);

    if (wp.withdrawal.processooor !== entrypointAddress) {
      throw WithdrawalValidationError.processooorMismatch(
        `Processooor mismatch: expected "${entrypointAddress}", got "${wp.withdrawal.processooor}".`,
      );
    }

    if (getAddress(feeRecipient) !== feeReceiverAddress) {
      throw WithdrawalValidationError.feeReceiverMismatch(
        `Fee recipient mismatch: expected "${feeReceiverAddress}", got "${feeRecipient}".`,
      );
    }

    const withdrawalContext = BigInt(
      this.sdkProvider.calculateContext(wp.withdrawal, wp.scope),
    );
    if (proofSignals.context !== withdrawalContext) {
      throw WithdrawalValidationError.contextMismatch(
        `Context mismatch: expected "${withdrawalContext.toString(16)}", got "${proofSignals.context.toString(16)}".`,
      );
    }

    const { assetAddress } = await this.sdkProvider.scopeData(wp.scope, chainId);
    
    // Get asset configuration for this chain and asset
    const assetConfig = getAssetConfig(chainId, assetAddress);
    
    if (!assetConfig) {
      throw WithdrawalValidationError.assetNotSupported(
        `Asset ${assetAddress} is not supported on chain ${chainId}.`
      );
    }
    
    if (relayFeeBPS !== assetConfig.fee_bps) {
      throw WithdrawalValidationError.feeMismatch(
        `Relay fee mismatch: expected "${assetConfig.fee_bps}", got "${relayFeeBPS}".`,
      );
    }
    
    if (proofSignals.withdrawnValue < assetConfig.min_withdraw_amount) {
      throw WithdrawalValidationError.withdrawnValueTooSmall(
        `Withdrawn value too small: expected minimum "${assetConfig.min_withdraw_amount}", got "${proofSignals.withdrawnValue}".`,
      );
    }
  }
}
