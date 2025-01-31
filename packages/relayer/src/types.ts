import { Address } from "viem/accounts";
import { RelayerResponse } from "./interfaces/relayer/request.js";

export abstract class RelayerMarshall {
  abstract toJSON(): object;
}

export class DetailsMarshall extends RelayerMarshall {
  constructor(
    private feeBPS: bigint,
    private feeReceiverAddress: Address,
  ) {
    super();
  }
  override toJSON(): object {
    return {
      feeBPS: this.feeBPS.toString(),
      feeReceiverAddress: this.feeReceiverAddress.toString(),
    };
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
