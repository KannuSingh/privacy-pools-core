import { NextFunction, Request, Response } from "express";
import { ValidationError } from "../../exceptions/base.exception.js";
import { validateDetailsQuerystring } from "../../schemes/relayer/details.scheme.js";
import { validateRelayRequestBody } from "../../schemes/relayer/request.scheme.js";

// Middleware to validate the details querying
export function validateDetailsMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const isValid = validateDetailsQuerystring(req.query);
  if (!isValid) {
    const messages: string[] = [];
    validateDetailsQuerystring.errors?.forEach(e => e?.message ? messages.push(e.message) : undefined);
    next(ValidationError.invalidQuerystring({ message: messages.join("\n") }));
    return;
  }
  next();
}

// Middleware to validate the relay-request body
export function validateRelayRequestMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const isValid = validateRelayRequestBody(req.body);
  if (!isValid) {
    const messages: string[] = [];
    validateRelayRequestBody.errors?.forEach(e => e?.message ? messages.push(e.message) : undefined);
    next(ValidationError.invalidInput({ message: messages.join("\n") }));
    return;
  }
  next();
}
