import { WithdrawalRelayerPayload } from "./request.js";

export interface QuotetBody {
  /** Chain ID to process the request on */
  chainId: string | number;
  /** Potential balance to withdraw */
  amount: string;
  /** Asset address */
  asset: string;
  /** Asset address */
  recipient?: string;
}

export interface QuoteResponse {
  baseFeeBPS: bigint,
  feeBPS: bigint,
  feeCommitment?: {
    expiration: number,
    withdrawalData: string
    signedRelayerCommitment: string
  }
}
