import { Hash, WithdrawalPayload } from "@privacy-pool-core/sdk";
import { NextFunction, Request, Response } from "express";
import { getAddress } from "viem";
import { ValidationError } from "../../exceptions/base.exception.js";
import {
  RelayerResponse,
  RelayRequestBody,
} from "../../interfaces/relayer/request.js";
import { validateRelayRequestBody } from "../../schemes/relayer/request.scheme.js";
import { RequestMashall } from "../../types.js";
import { PrivacyPoolRelayer } from "../../services/index.js";

function relayRequestBodyToWithdrawalPayload(
  body: RelayRequestBody,
): WithdrawalPayload {
  const proof = { ...body.proof, protocol: "groth16", curve: "bn128" };
  const publicSignals = body.publicSignals;
  const withdrawal = {
    procesooor: getAddress(body.withdrawal.procesooor),
    scope: BigInt(body.withdrawal.scope) as Hash,
    data: Uint8Array.from(Buffer.from(body.withdrawal.data, "hex")),
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
