import { NextFunction, Request, Response } from "express";
import { DetailsMarshall } from "../../types.js";
import { getAddress } from "viem/utils";
import { FEE_BPS, FEE_RECEIVER_ADDRESS } from "../../config.js";

export function relayerDetailsHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const feeBPS = BigInt(FEE_BPS);
  const feeReceiverAddress = getAddress(FEE_RECEIVER_ADDRESS);
  res
    .status(200)
    .json(
      res.locals.marshalResponse(
        new DetailsMarshall(feeBPS, feeReceiverAddress),
      ),
    );
  next();
}
