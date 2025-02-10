/**
 * Handles withdrawal requests within the Privacy Pool relayer.
 */
import { getAddress } from "viem";
import {
  ENTRYPOINT_ADDRESS,
  FEE_BPS,
  FEE_RECEIVER_ADDRESS,
  PROVIDER_URL,
  SIGNER_PRIVATE_KEY,
  WITHDRAW_AMOUNTS,
} from "../config.js";
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
  /** RPC URL for blockchain communication. */
  private readonly rpcUrl: string = PROVIDER_URL;
  /** Private key for signing transactions. */
  private readonly privateKey: string = SIGNER_PRIVATE_KEY;

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
   * @returns {Promise<RelayerResponse>} - A promise resolving to the relayer response.
   */
  async handleRequest(req: WithdrawalPayload): Promise<RelayerResponse> {
    const requestId = crypto.randomUUID();
    const timestamp = Date.now();

    try {
      await this.db.createNewRequest(requestId, timestamp, req);
      await this.validateWithdrawal(req);

      const isValidWithdrawalProof = await this.verifyProof(req.proof);
      if (!isValidWithdrawalProof) {
        throw ZkError.invalidProof();
      }

      const response = await this.broadcastWithdrawal(req);
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
   * @returns {Promise<{ hash: string }>} - A promise resolving to the transaction hash.
   */
  protected async broadcastWithdrawal(
    withdrawal: WithdrawalPayload,
  ): Promise<{ hash: string }> {
    return this.sdkProvider.broadcastWithdrawal(withdrawal);
  }

  /**
   * Validates a withdrawal request against relayer rules.
   *
   * @param {WithdrawalPayload} wp - The withdrawal payload.
   * @throws {WithdrawalValidationError} - If validation fails.
   * @throws {ValidationError} - If public signals are malformed.
   */
  protected async validateWithdrawal(wp: WithdrawalPayload) {
    const { feeRecipient, relayFeeBPS } = decodeWithdrawalData(
      wp.withdrawal.data,
    );
    const proofSignals = parseSignals(wp.proof.publicSignals);

    if (wp.withdrawal.processooor !== ENTRYPOINT_ADDRESS) {
      throw WithdrawalValidationError.processooorMismatch(
        `Processooor mismatch: expected "${ENTRYPOINT_ADDRESS}", got "${wp.withdrawal.processooor}".`,
      );
    }

    if (getAddress(feeRecipient) !== FEE_RECEIVER_ADDRESS) {
      throw WithdrawalValidationError.feeReceiverMismatch(
        `Fee recipient mismatch: expected "${FEE_RECEIVER_ADDRESS}", got "${feeRecipient}".`,
      );
    }

    if (relayFeeBPS !== FEE_BPS) {
      throw WithdrawalValidationError.feeMismatch(
        `Relay fee mismatch: expected "${FEE_BPS}", got "${relayFeeBPS}".`,
      );
    }

    const withdrawalContext = BigInt(
      this.sdkProvider.calculateContext(wp.withdrawal),
    );
    if (proofSignals.context !== withdrawalContext) {
      throw WithdrawalValidationError.contextMismatch(
        `Context mismatch: expected "${withdrawalContext.toString(16)}", got "${proofSignals.context.toString(16)}".`,
      );
    }

    const { assetAddress } = await this.sdkProvider.scopeData(
      wp.withdrawal.scope,
    );
    const MIN_WITHDRAW_DEFAULT = 100_000n;
    const minWithdrawAmount =
      WITHDRAW_AMOUNTS[assetAddress] ?? MIN_WITHDRAW_DEFAULT;
    if (proofSignals.withdrawnValue < minWithdrawAmount) {
      throw WithdrawalValidationError.withdrawnValueTooSmall(
        `Withdrawn value too small: expected minimum "${minWithdrawAmount}", got "${proofSignals.withdrawnValue}".`,
      );
    }
  }
}
