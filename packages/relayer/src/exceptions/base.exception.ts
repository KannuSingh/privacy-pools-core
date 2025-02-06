/**
 * Unified error codes for the Relayer.
 */
export enum ErrorCode {
  // Base errors
  UNKNOWN = "UNKNOWN",
  INVALID_INPUT = "INVALID_INPUT",

  // Withdrawal data assertions
  INVALID_DATA = "INVALID_DATA",
  INVALID_ABI = "INVALID_ABI",
  RECEIVER_MISMATCH = "RECEIVER_MISMATCH",
  FEE_MISMATCH = "FEE_MISMATCH",
  CONTEXT_MISMATCH = "CONTEXT_MISMATCH",
  INSUFFICIENT_WITHDRAWN_VALUE = "INSUFFICIENT_WITHDRAWN_VALUE",

  // Config errors
  INVALID_CONFIG = "INVALID_CONFIG",
  FEE_BPS_OUT_OF_BOUNDS = "FEE_BPS_OUT_OF_BOUNDS",
  CHAIN_NOT_SUPPORTED = "CHAIN_NOT_SUPPORTED",

  // Proof errors
  INVALID_PROOF = "INVALID_PROOF",

  // Contract errors
  CONTRACT_ERROR = "CONTRACT_ERROR",

  // SDK error. Wrapper for sdk's native errors
  SDK_ERROR = "SDK_ERROR",
}

/**
 * Base error class for the Relayer.
 * All other error classes should extend this.
 */
export class RelayerError extends Error {
  constructor(
    message: string,
    public readonly code: ErrorCode = ErrorCode.UNKNOWN,
    public readonly details?: Record<string, unknown> | string,
  ) {
    super(message);
    this.name = this.constructor.name;

    // Maintains proper stack trace
    Error.captureStackTrace(this, this.constructor);
  }

  /**
   * Creates a JSON representation of the error.
   */
  public toJSON(): Record<string, unknown> {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      details: this.details,
    };
  }

  public static unknown(message?: string): RelayerError {
    return new RelayerError(message || "", ErrorCode.UNKNOWN);
  }
}

export class ValidationError extends RelayerError {
  constructor(
    message: string,
    code: ErrorCode = ErrorCode.INVALID_INPUT,
    details?: Record<string, unknown>,
  ) {
    super(message, code, details);
    this.name = this.constructor.name;
  }

  /**
   * Creates an error for input validation failures.
   */
  public static invalidInput(
    details?: Record<string, unknown>,
  ): ValidationError {
    return new ValidationError(
      "Failed to parse request payload",
      ErrorCode.INVALID_INPUT,
      details,
    );
  }
}

export class ZkError extends RelayerError {
  constructor(
    message: string,
    code: ErrorCode = ErrorCode.INVALID_PROOF,
    details?: Record<string, unknown>,
  ) {
    super(message, code, details);
    this.name = this.constructor.name;
  }

  /**
   * Creates an error for input validation failures.
   */
  public static invalidProof(details?: Record<string, unknown>): ZkError {
    return new ZkError("Invalid proof", ErrorCode.INVALID_PROOF, details);
  }
}

export class ConfigError extends RelayerError {
  constructor(
    message: string,
    code: ErrorCode = ErrorCode.INVALID_CONFIG,
    details?: Record<string, unknown> | string,
  ) {
    super(message, code, details);
    this.name = this.constructor.name;
  }

  /**
   * Creates an error for input validation failures.
   */
  public static default(
    details?: Record<string, unknown> | string,
  ): ConfigError {
    return new ConfigError("Invalid config", ErrorCode.INVALID_CONFIG, details);
  }
}

export class WithdrawalValidationError extends RelayerError {
  constructor(
    message: string,
    code: ErrorCode = ErrorCode.INVALID_DATA,
    details?: Record<string, unknown> | string,
  ) {
    super(message, code, details);
    this.name = this.constructor.name;
  }

  public static invalidWithdrawalAbi(
    details?: Record<string, unknown>,
  ): WithdrawalValidationError {
    return new WithdrawalValidationError(
      "Failed to parse withdrawal data",
      ErrorCode.INVALID_ABI,
      details,
    );
  }

  public static feeReceiverMismatch(
    details: string,
  ): WithdrawalValidationError {
    return new WithdrawalValidationError(
      "Fee receiver does not match relayer",
      ErrorCode.RECEIVER_MISMATCH,
      details,
    );
  }

  public static feeMismatch(details: string) {
    return new WithdrawalValidationError(
      "Fee does not match relayer fee",
      ErrorCode.FEE_MISMATCH,
      details,
    );
  }

  public static contextMismatch(details: string) {
    return new WithdrawalValidationError(
      "Context does not match public signal",
      ErrorCode.CONTEXT_MISMATCH,
      details,
    );
  }

  public static withdrawnValueTooSmall(details: string) {
    return new WithdrawalValidationError(
      "Withdrawn value is too small",
      ErrorCode.INSUFFICIENT_WITHDRAWN_VALUE,
      details,
    );
  }
}

export class SdkError extends RelayerError {
  constructor(message: string, details?: Record<string, unknown> | string) {
    super(message, ErrorCode.SDK_ERROR, details);
    this.name = this.constructor.name;
  }

  public static scopeDataError(error: Error) {
    return new SdkError(`SdkError: SCOPE_DATA_ERROR ${error.message}`);
  }
}
