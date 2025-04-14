/**
 * Handles withdrawal requests within the Privacy Pool relayer.
 */
import { getAddress } from "viem";
import {
  getAssetConfig,
  getEntrypointAddress,
  getFeeReceiverAddress
} from "../config/index.js";
import {
  BlockchainError,
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
import { SdkProviderInterface } from "../types/sdk.types.js";
import { decodeWithdrawalData, isViemError, parseSignals } from "../utils.js";

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

      // simulate tx before broadcasting
      const simulationResult = await this.sdkProvider.simulateWithdrawal(req, chainId);

      if (!simulationResult.success) {
        const simulationError = simulationResult.error || "Unknown simulation failure";
        throw BlockchainError.txSimulationError(`Relay simulation failed: ${simulationError}`);
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
      let errorMessage: string;
      if (error instanceof RelayerError) {
        errorMessage = error.toPrettyString();
      } else {
        // TODO: we might want to remove all this section or refactor it for a cleaner web3 error parser into RelayerError types
        try {
          // Convert to string to handle both Error objects and other types
          const errorStr = typeof error === 'object' ? JSON.stringify(error, (key, value) =>
            typeof value === 'bigint' ? value.toString() : value) : String(error);

          // Try to parse the error if it's JSON
          const errorObj = JSON.parse(errorStr);

          // Extract contract error message if available
          if (errorObj.cause?.metaMessages && errorObj.cause.metaMessages.length > 0) {
            // First message is usually the contract error
            const contractError = errorObj.cause.metaMessages[0].trim();
            errorMessage = contractError.startsWith('Error:')
              ? contractError.substring(6).trim()
              : contractError;
          } else if (errorObj.shortMessage) {
            errorMessage = errorObj.shortMessage;
          } else {
            errorMessage = "Unknown contract error";
          }
        } catch {
          // If we can't parse the error, just use the string representation
          errorMessage = String(error);
        }
      }

      await this.db.updateFailedRequest(requestId, errorMessage);
      return {
        success: false,
        error: errorMessage,
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
    try {
      return await this.sdkProvider.broadcastWithdrawal(withdrawal, chainId);
    } catch (error) {
      if (isViemError(error)) {
        const { metaMessages, shortMessage } = error;
        throw BlockchainError.txError((metaMessages ? metaMessages[0] : undefined) || shortMessage)
      } else {
        throw RelayerError.unknown("Something went wrong while broadcasting Tx")
      }
    }
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
