import { Address } from "viem";
import { quoteProvider, web3Provider } from "../providers/index.js";

interface QuoteFeeBPSParams {
  chainId: number,
  assetAddress: Address,
  amountIn: bigint,
  value: bigint,
  baseFeeBPS: bigint
};

export class QuoteService {

  async quoteFeeBPSNative(quoteParams: QuoteFeeBPSParams): Promise<bigint> {
    const { chainId, assetAddress, amountIn, baseFeeBPS, value } = quoteParams;
    const gasPrice = await web3Provider.getGasPrice(chainId);
    const quote = await quoteProvider.quoteNativeTokenInERC20(chainId, assetAddress, amountIn);
    const feeBPS = await quoteProvider.quoteFeeBPSNative(baseFeeBPS, amountIn, quote, gasPrice, value);
    return feeBPS
  }

}
