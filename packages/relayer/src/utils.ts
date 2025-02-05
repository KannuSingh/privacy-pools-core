import { decodeAbiParameters, DecodeAbiParametersErrorType } from "viem";
import {
  ValidationError,
  WithdrawalValidationError,
} from "./exceptions/base.exception.js";
import { FeeDataAbi } from "./types/abi.types.js";
import {
  RelayRequestBody,
  WithdrawPublicSignals,
} from "./interfaces/relayer/request.js";

export function decodeWithdrawalData(data: `0x${string}`) {
  try {
    const [{ recipient, feeRecipient, relayFeeBPS }] = decodeAbiParameters(
      FeeDataAbi,
      data,
    );
    return { recipient, feeRecipient, relayFeeBPS };
  } catch (e) {
    const error = e as DecodeAbiParametersErrorType;
    throw WithdrawalValidationError.invalidWithdrawalAbi({
      name: error.name,
      message: error.message,
    });
  }
}

export function parseSignals(
  signals: RelayRequestBody["publicSignals"],
): WithdrawPublicSignals {
  const badSignals = signals
    .map((x, i) => (x === undefined ? i : null))
    .filter((i) => i !== null);
  if (badSignals.length > 0) {
    throw ValidationError.invalidInput({
      details: `Signals ${badSignals.join(", ")} are undefined`,
    });
  }
  /// XXX: beware this signal distribution is based on how the circuits were compiled with circomkit, first 2 are the public outputs, next are the public inputs
  return {
    newCommitmentHash: BigInt(signals[0]!), // Hash of new commitment
    existingNullifierHash: BigInt(signals[1]!), // Hash of the existing commitment nullifier
    withdrawnValue: BigInt(signals[2]!),
    stateRoot: BigInt(signals[3]!),
    stateTreeDepth: BigInt(signals[4]!),
    ASPRoot: BigInt(signals[5]!),
    ASPTreeDepth: BigInt(signals[6]!),
    context: BigInt(signals[7]!),
  };
}
