import { NextFunction, Request, Response } from "express";
import { validateRelayRequestBody } from "../../schemes/relayer/request.scheme.js";

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
