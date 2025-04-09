import { NextFunction, Request, Response } from "express";
import { getAddress } from "viem";
import { getAssetConfig, getFeeReceiverAddress } from "../../config/index.js";
import { QuoterError } from "../../exceptions/base.exception.js";
import { quoteProvider, web3Provider } from "../../providers/index.js";
import { QuoteMarshall } from "../../types.js";
import { encodeWithdrawalData } from "../../utils.js";

const TIME_20_SECS = 20 * 1000;

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

  const recipient = req.body.recipient ? getAddress(req.body.recipient.toString()) : undefined

  const quoteResponse = new QuoteMarshall({
    baseFeeBPS: config.fee_bps,
    feeBPS,
  });

  if (recipient) {
    const feeReceiverAddress = getFeeReceiverAddress(chainId);
    const withdrawalData = encodeWithdrawalData({
      feeRecipient: getAddress(feeReceiverAddress),
      recipient,
      relayFeeBPS: feeBPS
    })
    const expiration = Number(new Date()) + TIME_20_SECS
    const relayerCommitment = { withdrawalData, expiration };
    const signedRelayerCommitment = await web3Provider.signRelayerCommitment(chainId, relayerCommitment);
    quoteResponse.addFeeCommitment({ expiration, withdrawalData, signedRelayerCommitment })
  }

  res
    .status(200)
    .json(res.locals.marshalResponse(quoteResponse));

}
