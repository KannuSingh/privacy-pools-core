import { NextFunction, Request, Response } from "express";
import { getAddress } from "viem";
import { getAssetConfig } from "../../config/index.js";
import { RelayerError } from "../../exceptions/base.exception.js";
import { web3Provider } from "../../providers/index.js";
import { QuoteProvider } from "../../providers/quote.provider.js";
import { QuoteMarshall } from "../../types.js";

const TIME_30_SECS = 30 * 1000;

export async function relayQuoteHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {

  const chainId = Number(req.body.chain_id!);
  const amountIn = BigInt(req.body.amount!.toString());
  const tokenAddress = getAddress(req.body.token!.toString())

  const config = getAssetConfig(chainId, tokenAddress);
  if (config === undefined)
    throw RelayerError.unknown(`Asset ${tokenAddress} for chain ${chainId} is not supported`)

  const quoteProvider = new QuoteProvider(config.fee_bps);
  const gasPrice = await web3Provider.getGasPrice(chainId);
  const value = 0n;

  const quote = await quoteProvider.quoteNativeTokenInERC20(chainId, tokenAddress, amountIn);
  const feeBPS = await quoteProvider.quoteFeeBPSNative(amountIn, quote, gasPrice, value);

  res
    .status(200)
    .json(res.locals.marshalResponse(new QuoteMarshall({ feeBPS, expiration: Number(new Date()) + TIME_30_SECS, relayToken: "" })));

}
