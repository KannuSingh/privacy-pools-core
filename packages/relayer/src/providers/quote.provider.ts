import { Address } from "viem";
import { uniswapProvider } from "./index.js";

export class QuoteProvider {

  static txCost: bigint = 700_000n;

  constructor(readonly baseFee: bigint) {
  }

  async quoteNativeTokenInERC20(chainId: number, addressIn: Address, amountIn: bigint): Promise<{ num: bigint, den: bigint }> {
    const { in: in_, out } = (await uniswapProvider.quoteNativeToken(chainId, addressIn, amountIn))!;
    return { num: out.amount, den: in_.amount };
  }

  async quoteFeeBPSNative(balance: bigint, nativeQuote: { num: bigint, den: bigint }, gasPrice: bigint, value: bigint): Promise<bigint> {
    const nativeCosts = (1n * gasPrice * QuoteProvider.txCost + value)
    return this.baseFee + nativeQuote.den * 10_000n * nativeCosts / balance / nativeQuote.num;
  }

}
