import { NextFunction, Request, Response } from "express";
import { DetailsMarshall } from "../../types.js";
import { getAddress } from "viem/utils";
import { CONFIG, getAssetConfig, getChainConfig } from "../../config/index.js";
import { ConfigError, ValidationError } from "../../exceptions/base.exception.js";

/**
 * Handler for the relayer details endpoint.
 * Supports querying by chain ID and asset address.
 * Returns details about the fee structure for a specific asset on a specific chain.
 * 
 * @param {Request} req - The HTTP request.
 * @param {Response} res - The HTTP response.
 * @param {NextFunction} next - The next middleware function.
 */
export function relayerDetailsHandler(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    // Get query parameters
    const chainIdParam = req.query.chainId as string | undefined;
    const assetAddressParam = req.query.assetAddress as string | undefined;
    
    // Both parameters must be provided
    if (!chainIdParam) {
      throw ValidationError.invalidInput({ message: "Chain ID is required" });
    }
    
    if (!assetAddressParam) {
      throw ValidationError.invalidInput({ message: "Asset address is required" });
    }
    
    // Parse chain ID
    const parsedChainId = parseInt(chainIdParam, 10);
    if (isNaN(parsedChainId)) {
      throw ValidationError.invalidInput({ message: "Invalid chain ID format" });
    }
    const chainId = parsedChainId;
    
    // Get chain configuration
    try {
      const chainConfig = getChainConfig(chainId);
      
      // Get fee receiver address for this chain
      const feeReceiverAddress = chainConfig.fee_receiver_address || CONFIG.defaults.fee_receiver_address;
      
      try {
        const normalizedAssetAddress = getAddress(assetAddressParam);
        const assetConfig = getAssetConfig(chainId, normalizedAssetAddress);
        
        if (!assetConfig) {
          throw ValidationError.invalidInput({ 
            message: `Asset ${normalizedAssetAddress} not supported on chain ${chainId}` 
          });
        }
        
        // Return details for the specific asset
        res.status(200).json(
          res.locals.marshalResponse(
            new DetailsMarshall(
              assetConfig.fee_bps,
              getAddress(feeReceiverAddress),
              chainId,
              normalizedAssetAddress,
              assetConfig.min_withdraw_amount
            )
          )
        );
      } catch (error) {
        if (error instanceof ValidationError) {
          throw error;
        }
        throw ValidationError.invalidInput({ message: "Invalid asset address format" });
      }
    } catch (error) {
      if (error instanceof ConfigError || error instanceof ValidationError) {
        throw error;
      }
      throw ConfigError.default(`Chain with ID ${chainId} not supported`);
    }
  } catch (error) {
    console.error("Error in relayer details handler:", error);
    
    if (error instanceof ConfigError) {
      res.status(400).json({ 
        error: error.message,
        code: error.code
      });
    } else if (error instanceof ValidationError) {
      res.status(400).json({ 
        error: error.message,
        code: error.code,
        details: error.details
      });
    } else {
      res.status(500).json({ error: "Internal server error" });
    }
  }
  
  next();
}
