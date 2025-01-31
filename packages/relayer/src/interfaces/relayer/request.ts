export interface ProofRelayerPayload {
  pi_a: string[];
  pi_b: string[][];
  pi_c: string[];
}

/**
 * Withdrawal
 */
export interface WithdrawalRelayerPayload {
  /**
   * Relayer address (0xAdDrEsS)
   */
  procesooor: string;
  /**
   * Relayer scope (bigint as string)
   */
  scope: string;
  /**
   * Tx data (hex encoded)
   */
  data: string;
}

export interface RelayRequestBody {
  withdrawal: WithdrawalRelayerPayload;
  publicSignals: string[];
  proof: ProofRelayerPayload;
}

export interface RelayerResponse {
  success: boolean;
  timestamp: number;
  requestId: string;
  txHash?: string;
  error?: string;
}

export const enum RequestStatus {
  BROADCASTED = "BROADCASTED",
  FAILED = "FAILED",
  RECEIVED = "RECEIVED",
}
