import path from "node:path";
import fs from "node:fs";
import { getAddress } from "viem";
import { ConfigError } from "./exceptions/base.exception.js";

const enum ConfigEnv {
  FEE_RECEIVER_ADDRESS = "FEE_RECEIVER_ADDRESS",
  PROVIDER_URL = "PROVIDER_URL",
  SIGNER_PRIVATE_KEY = "SIGNER_PRIVATE_KEY",
  FEE_BPS = "FEE_BPS",
  SQLITE_DB_PATH = "SQLITE_DB_PATH",
}

type ConfigEnvString = `${ConfigEnv}`;

interface ConfigEnvVarChecker {
  (varNameValue: string): void;
}

function checkConfigVar(
  varName: ConfigEnvString,
  checker?: ConfigEnvVarChecker,
) {
  const varNameValue = process.env[varName];
  if (varNameValue === undefined) {
    throw ConfigError.default({
      context: `Environment variable \`${varName}\` is undefined`,
    });
  }
  if (checker) {
    try {
      checker(varNameValue);
    } catch (error) {
      console.error(error);
      throw ConfigError.default({
        context: `Environment variable \`${varName}\` has an incorrect format`,
      });
    }
  }
  return varNameValue;
}

function getFeeReceiverAddress(): string {
  return checkConfigVar(ConfigEnv.FEE_RECEIVER_ADDRESS, (v) => getAddress(v));
}

function getProviderURL() {
  // TODO: check provider url format
  return checkConfigVar(ConfigEnv.PROVIDER_URL);
}

function getSignerPrivateKey() {
  // TODO: check pk format
  return checkConfigVar(ConfigEnv.SIGNER_PRIVATE_KEY);
}

function getFeeBps() {
  // TODO: check feeBPS format
  return checkConfigVar(ConfigEnv.FEE_BPS);
}

function getSqliteDbPath() {
  // check path exists of warn of new one
  return checkConfigVar(ConfigEnv.SQLITE_DB_PATH, (v) => {
    const dbPath = path.resolve(v);
    if (!fs.existsSync(v)) {
      console.log("Creating new DB at", dbPath);
    }
  });
}

export const FEE_RECEIVER_ADDRESS = getFeeReceiverAddress();
export const PROVIDER_URL = getProviderURL();
export const SIGNER_PRIVATE_KEY = getSignerPrivateKey();
export const FEE_BPS = getFeeBps();
export const SQLITE_DB_PATH = getSqliteDbPath();
