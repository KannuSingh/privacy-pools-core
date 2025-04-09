import { NextFunction, Request, Response } from "express";
import { getAddress } from "viem";
import { getAssetConfig } from "../../config/index.js";
import { QuoterError } from "../../exceptions/base.exception.js";
import { quoteProvider, web3Provider } from "../../providers/index.js";
import { QuoteMarshall } from "../../types.js";

export async function relayQuoteHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {

  const chainId = Number(req.body.chainId!);
  const amountIn = BigInt(req.body.amount!.toString());
  const tokenAddress = getAddress(req.body.asset!.toString())

  const config = getAssetConfig(chainId, tokenAddress);
  if (config === undefined)
    return next(QuoterError.assetNotSupported(`Asset ${tokenAddress} for chain ${chainId} is not supported`));

  const gasPrice = await web3Provider.getGasPrice(chainId);
  const value = 0n;  // for future features

  const quote = await quoteProvider.quoteNativeTokenInERC20(chainId, tokenAddress, amountIn);
  const feeBPS = await quoteProvider.quoteFeeBPSNative(config.fee_bps, amountIn, quote, gasPrice, value);

  res
    .status(200)
    .json(res.locals.marshalResponse(new QuoteMarshall({
      baseFeeBPS: config.fee_bps,
      feeBPS,
    })));

}
