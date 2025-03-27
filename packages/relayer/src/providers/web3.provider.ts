import { Chain, createPublicClient, http, PublicClient } from "viem";
import {
  CONFIG
} from "../config/index.js";
import { createChainObject } from "../utils.js";

interface IWeb3Provider {
}

/**
 * Class representing the provider for interacting with several chains
 */
export class Web3Provider implements IWeb3Provider {
  chains: { [key: number]: Chain };
  clients: { [key: number]: PublicClient };

  constructor() {
    this.chains = Object.fromEntries(CONFIG.chains.map(chainConfig => {
      return [chainConfig.chain_id, createChainObject(chainConfig)];
    }));
    this.clients = Object.fromEntries(Object.entries(this.chains).map(([chainId, chain]) => {
      return [
        chainId,
        createPublicClient({
          chain,
          transport: http(chain.rpcUrls.default.http[0])
        })];
    }))
  }

  client(chainId: number): PublicClient {
    const client = this.clients[chainId];
    if (client === undefined) {
      throw Error(`Web3ProviderError::UnsupportedChainId(${chainId})`)
    }
    else return client
  }

  async getGasPrice(chainId: number): Promise<bigint> {
    return await this.client(chainId).getGasPrice()
  }

}
