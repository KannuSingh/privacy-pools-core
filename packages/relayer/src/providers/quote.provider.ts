import { Address } from "viem";
import { uniswapProvider } from "./index.js";

export class QuoteProvider {

  // a typical withdrawal costs between 450k-650k gas
  static txCost: bigint = 700_000n;

  constructor() {
  }

  async quoteNativeTokenInERC20(chainId: number, addressIn: Address, amountIn: bigint): Promise<{ num: bigint, den: bigint }> {
    const { in: in_, out } = (await uniswapProvider.quoteNativeToken(chainId, addressIn, amountIn))!;
    return { num: out.amount, den: in_.amount };
  }

  async quoteFeeBPSNative(baseFee: bigint, balance: bigint, nativeQuote: { num: bigint, den: bigint }, gasPrice: bigint, value: bigint): Promise<bigint> {
    const nativeCosts = (1n * gasPrice * QuoteProvider.txCost + value)
    return baseFee + nativeQuote.den * 10_000n * nativeCosts / balance / nativeQuote.num;
  }

}
