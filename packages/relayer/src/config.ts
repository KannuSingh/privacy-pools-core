import path from "node:path";
import fs from "node:fs";
import { Address, Chain, defineChain, getAddress, Hex, isHex } from "viem";
import { ConfigError } from "./exceptions/base.exception.js";
import { localhost, mainnet, sepolia } from "viem/chains";

const enum ConfigEnv {
  CONFIG_PATH = "CONFIG_PATH",
  FEE_RECEIVER_ADDRESS = "FEE_RECEIVER_ADDRESS",
  ENTRYPOINT_ADDRESS = "ENTRYPOINT_ADDRESS",
  PROVIDER_URL = "PROVIDER_URL",
  SIGNER_PRIVATE_KEY = "SIGNER_PRIVATE_KEY",
  FEE_BPS = "FEE_BPS",
  SQLITE_DB_PATH = "SQLITE_DB_PATH",
  CHAIN = "CHAIN",
  CHAIN_ID = "CHAIN_ID",
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
      if (error instanceof ConfigError) {
        throw error;
      } else {
        throw ConfigError.default({
          context: `Environment variable \`${varName}\` has an incorrect format`,
        });
      }
    }
  }
  return varNameValue;
}

function checkHex(v: string) {
  if (!isHex(v, { strict: true })) {
    throw ConfigError.default({
      context: `String ${v} is not a properly formatted hex string`,
    });
  }
}

function getFeeReceiverAddress(): Address {
  return getAddress(
    checkConfigVar(ConfigEnv.FEE_RECEIVER_ADDRESS, (v) => getAddress(v)),
  );
}

function getEntrypointAddress(): Address {
  return getAddress(
    checkConfigVar(ConfigEnv.ENTRYPOINT_ADDRESS, (v) => getAddress(v)),
  );
}

function getProviderURL() {
  // TODO: check provider url format
  return checkConfigVar(ConfigEnv.PROVIDER_URL);
}

function getSignerPrivateKey() {
  // TODO: check pk format
  return checkConfigVar(ConfigEnv.SIGNER_PRIVATE_KEY, checkHex) as Hex;
}

function getFeeBps() {
  // TODO: check feeBPS format
  const feeBps = BigInt(checkConfigVar(ConfigEnv.FEE_BPS));
  // range validation
  if (feeBps > 10_000n || feeBps < 0) {
    throw ConfigError.feeBpsOutOfBounds();
  }
  return feeBps;
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

function getMinWithdrawAmounts(): Record<string, bigint> {
  const envVar = checkConfigVar(ConfigEnv.CONFIG_PATH, (v) => {
    const configPath = path.resolve(v);
    if (!fs.existsSync(v)) {
      throw ConfigError.default({
        context: `${configPath} does not exist.`,
      });
    }
  });
  const withdrawAmountsRaw = JSON.parse(
    fs.readFileSync(path.resolve(envVar), { encoding: "utf-8" }),
  );
  const withdrawAmounts: Record<string, bigint> = {};
  for (const entry of Object.entries(withdrawAmountsRaw)) {
    const [asset, amount] = entry;
    if (typeof amount === "string" || typeof amount === "number") {
      withdrawAmounts[asset] = BigInt(amount);
    } else {
      console.error(`Unable to parse asset ${asset} with value ${amount}`);
    }
  }
  return withdrawAmounts;
}

function getChainConfig(): Chain {
  const chainName = checkConfigVar(ConfigEnv.CHAIN);
  const chainId = process.env[ConfigEnv.CHAIN_ID];
  return ((chainNameValue) => {
    switch (chainNameValue) {
      case "localhost":
        if (chainId) {
          return defineChain({ ...localhost, id: Number(chainId) });
        }
        return localhost;
      case "sepolia":
        return sepolia;
      case "mainnet":
        return mainnet;
      default:
        throw ConfigError.chainNotSupported();
    }
  })(chainName);
}

export const FEE_RECEIVER_ADDRESS = getFeeReceiverAddress();
export const ENTRYPOINT_ADDRESS = getEntrypointAddress();
export const PROVIDER_URL = getProviderURL();
export const SIGNER_PRIVATE_KEY = getSignerPrivateKey();
export const FEE_BPS = getFeeBps();
export const SQLITE_DB_PATH = getSqliteDbPath();
export const WITHDRAW_AMOUNTS = getMinWithdrawAmounts();
export const CHAIN = getChainConfig();
