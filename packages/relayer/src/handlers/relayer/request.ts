import { Hash } from "@privacy-pool-core/sdk";
import { NextFunction, Request, Response } from "express";
import { getAddress } from "viem";
import { ValidationError } from "../../exceptions/base.exception.js";
import {
  RelayerResponse,
  RelayRequestBody,
  WithdrawalPayload,
} from "../../interfaces/relayer/request.js";
import { validateRelayRequestBody } from "../../schemes/relayer/request.scheme.js";
import { PrivacyPoolRelayer } from "../../services/index.js";
import { RequestMashall } from "../../types.js";

/**
 * Converts a RelayRequestBody into a WithdrawalPayload.
 *
 * @param {RelayRequestBody} body - The relay request body containing proof and withdrawal details.
 * @returns {WithdrawalPayload} - The formatted withdrawal payload.
 */
function relayRequestBodyToWithdrawalPayload(
  body: RelayRequestBody,
): WithdrawalPayload {
  const proof = { ...body.proof, protocol: "groth16", curve: "bn128" };
  const publicSignals = body.publicSignals;
  const withdrawal = {
    processooor: getAddress(body.withdrawal.processooor),
    scope: BigInt(body.withdrawal.scope) as Hash,
    data: body.withdrawal.data as `0x{string}`,
  };
  const wp = {
    proof: {
      proof,
      publicSignals,
    },
    withdrawal,
  };
  return wp;
}

/**
 * Parses and validates the withdrawal request body.
 *
 * @param {Request["body"]} body - The request body to parse.
 * @returns {WithdrawalPayload} - The validated and formatted withdrawal payload.
 * @throws {ValidationError} - If the input data is invalid.
 */
function parseWithdrawal(body: Request["body"]): WithdrawalPayload {
  if (validateRelayRequestBody(body)) {
    try {
      return relayRequestBodyToWithdrawalPayload(body);
    } catch (error) {
      console.error(error);
      // TODO: extend this catch to return more details about the issue (viem error, node error, etc)
      throw ValidationError.invalidInput({
        message: "Can't parse payload into SDK structure",
      });
    }
  } else {
    throw ValidationError.invalidInput({ message: "Payload format error" });
  }
}

/**
 * Express route handler for relaying requests.
 *
 * @param {Request} req - The incoming HTTP request.
 * @param {Response} res - The HTTP response object.
 * @param {NextFunction} next - The next middleware function.
 */
export async function relayRequestHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const privacyPoolRelayer = new PrivacyPoolRelayer();
    const withdrawalPayload = parseWithdrawal(req.body);
    const requestResponse: RelayerResponse =
      await privacyPoolRelayer.handleRequest(withdrawalPayload);
    res
      .status(200)
      .json(res.locals.marshalResponse(new RequestMashall(requestResponse)));
    next();
  } catch (error) {
    next(error);
  }
}
