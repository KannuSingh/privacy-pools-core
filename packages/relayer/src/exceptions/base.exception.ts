/**
 * Unified error codes for the Relayer.
 */
export enum ErrorCode {
  // Base errors
  UNKNOWN = "UNKNOWN",
  INVALID_INPUT = "INVALID_INPUT",

  // Config errors
  INVALID_CONFIG = "INVALID_CONFIG",

  // Proof errors
  INVALID_PROOF = "INVALID_PROOF",

  // Contract errors
  CONTRACT_ERROR = "CONTRACT_ERROR",
}

/**
 * Base error class for the Relayer.
 * All other error classes should extend this.
 */
export class RelayerError extends Error {
  constructor(
    message: string,
    public readonly code: ErrorCode = ErrorCode.UNKNOWN,
    public readonly details?: Record<string, unknown>,
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
    details?: Record<string, unknown>,
  ) {
    super(message, code, details);
    this.name = this.constructor.name;
  }

  /**
   * Creates an error for input validation failures.
   */
  public static default(details?: Record<string, unknown>): ConfigError {
    return new ConfigError("Invalid config", ErrorCode.INVALID_CONFIG, details);
  }

  public static unknown(message: string): ConfigError {
    return new ConfigError("Invalid config", ErrorCode.INVALID_CONFIG, {
      context: `Unknown error for ${message}`,
    });
  }
}
