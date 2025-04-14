import { Address } from "viem";
import { uniswapProvider } from "./index.js";

export class QuoteProvider {

  constructor() {
  }

  async quoteNativeTokenInERC20(chainId: number, addressIn: Address, amountIn: bigint): Promise<{ num: bigint, den: bigint }> {
    const { in: in_, out } = (await uniswapProvider.quoteNativeToken(chainId, addressIn, amountIn))!;
    return { num: out.amount, den: in_.amount };
  }

}
