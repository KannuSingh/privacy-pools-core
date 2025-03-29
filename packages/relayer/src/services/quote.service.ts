import { uniswapService } from "./index.js";

export class QuoteService {

  static feeNet: bigint = 100n;
  static txCost: bigint = 700_000n;

  static async quoteFeeBPSNative(balance: bigint, nativeQuote: bigint, gasPrice: bigint, value: bigint): Promise<bigint> {
    let tokenQuote = await uniswapService.quote({
      chainId: 137,
      inToken: "0x0000000000000000000000000000000000000000",
      outToken: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
      inAmount: 10000000000000000000n
    });
    console.log(tokenQuote)
    return 0n
  }
}
