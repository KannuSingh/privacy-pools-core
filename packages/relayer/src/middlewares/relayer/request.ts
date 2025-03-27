import { NextFunction, Request, Response } from "express";
import { validateRelayRequestBody } from "../../schemes/relayer/request.scheme.js";
import { validateDetailsQuerystring } from "../../schemes/relayer/details.scheme.js";
import { ValidationError } from "../../exceptions/base.exception.js";

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
    res.status(400).json({
      error: "Validation Error",
      details: validateRelayRequestBody.errors,
    });
    return;
  }
  next();
}
