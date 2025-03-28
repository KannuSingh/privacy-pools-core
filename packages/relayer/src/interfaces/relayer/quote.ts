import { WithdrawalRelayerPayload } from "./request.js";

export interface QuotetBody {
  /** Withdrawal details */
  withdrawal: WithdrawalRelayerPayload;
  /** Pool scope */
  scope: string;
  /** Chain ID to process the request on */
  chainId: string | number;
  /** Potential balance to withdraw */
  balance: string | number;
}

export interface QuoteResponse {
  feeBPS: bigint,
  expiration: number,
  relayToken: string
}
