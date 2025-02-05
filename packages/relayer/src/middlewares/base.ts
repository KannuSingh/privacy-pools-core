import { NextFunction, Request, Response } from "express";
import { RelayerError } from "../exceptions/base.exception.js";
import { RelayerMarshall } from "../types.js";

/**
 * Middleware to attach a marshaller function to the response locals.
 * This function formats the response data in a standardized way.
 *
 * @param {Request} _req - Express request object (unused).
 * @param {Response} res - Express response object.
 * @param {NextFunction} next - Express next function.
 */
export function marshalResponseMiddleware(
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  res.locals.marshalResponse = (data: RelayerMarshall) => ({
    ...data.toJSON(),
  });
  next();
}

/**
 * Middleware to handle errors and send appropriate responses.
 *
 * @param {Error} err - The error object.
 * @param {Request} _req - Express request object (unused).
 * @param {Response} res - Express response object.
 * @param {NextFunction} next - Express next function.
 */
export function errorHandlerMiddleware(
  err: Error,
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  if (err instanceof RelayerError) {
    // TODO: error handling based on RelayerError subtypes should be done by checking `err.name`
    res.status(400).json({ error: err.toJSON() });
  } else {
    res.status(500).json({ error: "Internal Server Error" });
  }
  next();
}

/**
 * Middleware to handle 404 (Not Found) responses.
 * If no response has been sent, it returns a 404 error.
 *
 * @param {Request} _req - Express request object (unused).
 * @param {Response} res - Express response object.
 * @param {NextFunction} next - Express next function.
 */
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
