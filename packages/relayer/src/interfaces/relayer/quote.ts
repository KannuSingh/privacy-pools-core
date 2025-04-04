import { WithdrawalRelayerPayload } from "./request.js";

export interface QuotetBody {
  /** Chain ID to process the request on */
  chainId: string | number;
  /** Potential balance to withdraw */
  amount: string;
  /** Asset address */
  asset: string;
  /** Asset address */
  address?: string;
}

export interface QuoteResponse {
  feeBPS: bigint,
  expiration: number,
  relayToken: string
}
