import { NextFunction, Request, Response } from "express";
import { QuoteMarshall } from "../../types.js";
import { quoteService } from "../../services/index.js";
import { QuoteService } from "../../services/quote.service.js";

export async function relayQuoteHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {

  await QuoteService.quoteFeeBPSNative(0n, 0n, 0n, 0n);

    res
      .status(200)
      .json(res.locals.marshalResponse(new QuoteMarshall({feeBPS: 10n, expiration: 1222, relayToken: ""})));
}
