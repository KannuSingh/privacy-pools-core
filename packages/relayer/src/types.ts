import { Address } from "viem/accounts";
import { RelayerResponse } from "./interfaces/relayer/request.js";

export abstract class RelayerMarshall {
  abstract toJSON(): object;
}

export class DetailsMarshall extends RelayerMarshall {
  constructor(
    private feeBPS: bigint,
    private feeReceiverAddress: Address,
    private chainId?: number,
    private assetAddress?: Address,
    private minWithdrawAmount?: bigint,
    private maxGasPrice?: bigint,
  ) {
    super();
  }
  override toJSON(): object {
    const result: Record<string, string | number | undefined> = {
      feeBPS: this.feeBPS.toString(),
      feeReceiverAddress: this.feeReceiverAddress.toString(),
    };
    
    if (this.chainId !== undefined) {
      result.chainId = this.chainId;
    }
    
    if (this.assetAddress !== undefined) {
      result.assetAddress = this.assetAddress.toString();
    }
    
    if (this.minWithdrawAmount !== undefined) {
      result.minWithdrawAmount = this.minWithdrawAmount.toString();
    }
    
    if (this.maxGasPrice !== undefined) {
      result.maxGasPrice = this.maxGasPrice.toString(10);
    }
    else {
      result.maxGasPrice = "0";
    }
    
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
