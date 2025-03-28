import { NextFunction, Request, Response } from "express";
import { QuoteMarshall } from "../../types.js";

export function relayQuoteHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
    res
      .status(200)
      .json(res.locals.marshalResponse(new QuoteMarshall({feeBPS: 10n, expiration: 1222, relayToken: ""})));
}
