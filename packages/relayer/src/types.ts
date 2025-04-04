import { Address } from "viem/accounts";
import { RelayerResponse } from "./interfaces/relayer/request.js";
import { QuoteResponse } from "./interfaces/relayer/quote.js";

export abstract class RelayerMarshall {
  abstract toJSON(): object;
}

export class DetailsMarshall extends RelayerMarshall {
  constructor(private details: {
    feeBPS: bigint,
    feeReceiverAddress: Address,
    chainId?: number,
    assetAddress?: Address,
    minWithdrawAmount?: bigint,
  }) {
    super();
  }
  override toJSON(): object {
    const result: Record<string, string | number | undefined> = {
      feeBPS: this.details.feeBPS.toString(),
      feeReceiverAddress: this.details.feeReceiverAddress.toString(),
      chainId: this.details.chainId,
      assetAddress: this.details.assetAddress?.toString(),
      minWithdrawAmount: this.details.minWithdrawAmount?.toString(),
    };
    return result;
  }
}

export class RequestMashall extends RelayerMarshall {
  constructor(readonly response: RelayerResponse) {
    super();
  }
  override toJSON(): object {
    return this.response;
  }
}

export class QuoteMarshall extends RelayerMarshall {
  constructor(readonly response: QuoteResponse) {
    super();
  }
  override toJSON(): object {
    return {
      feeBPS: this.response.feeBPS.toString(),
      expiration: this.response.expiration,
      relayToken: this.response.relayToken
    }
  }
}
