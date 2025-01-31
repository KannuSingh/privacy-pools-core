import { NextFunction, Request, Response } from "express";
import { RelayerError } from "../exceptions/base.exception.js";
import { RelayerMarshall } from "../types.js";

export function marshalResponseMiddleware(
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  res.locals.marshalResponse = (data: RelayerMarshall) => ({
    success: true,
    data: data.toJSON(),
  });
  next();
}

export function errorHandlerMiddleware(
  err: Error,
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  if (err instanceof RelayerError) {
    // TODO: error handling based in RelayerError subtypes should be done by checking `err.name`
    res.status(400).json({ error: err.toJSON() });
  } else {
    res.status(500).json({ error: "Internal Server Error" });
  }
  next();
}

export function notFoundMiddleware(
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  if (!res.writableFinished) {
    res.status(404).json({ error: "Route not found" });
  }
  next();
}
