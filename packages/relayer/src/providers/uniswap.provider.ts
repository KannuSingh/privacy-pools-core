import { Token } from '@uniswap/sdk-core'
import { FeeAmount } from '@uniswap/v3-sdk'
import { Address, getContract } from 'viem'

import { web3Provider } from '../providers/index.js'
import { RelayerError } from '../exceptions/base.exception.js'
import { QUOTER_CONTRACT_ADDRESS, WRAPPED_NATIVE_TOKEN_ADDRESS } from './uniswap/constants.js'
import { IERC20MinimalABI } from './uniswap/erc20.abi.js'
import { QuoterV2ABI } from './uniswap/quoterV2.abi.js'

export type UniswapQuote = {
  chainId: number;
  addressIn: string;
  addressOut: string;
  amountIn: bigint;
};

type QuoteToken = { amount: bigint, decimals: number }
export type Quote = {
  in: QuoteToken
  out: QuoteToken
};

const UNISWAP_V3_FACTORY_ADDRESS: Record<string, Address> = {
  '1': '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  '11155111': '0x0227628f3F023bb0B980b67D528571c95c6DaC1c',
};

export class UniswapProvider {
  async getTokenInfo(chainId: number, address: Address): Promise<Token> {
    const contract = getContract({
      address,
      abi: IERC20MinimalABI.abi,
      client: web3Provider.client(chainId)
    });
    const [decimals, symbol] = await Promise.all([
      contract.read.decimals(),
      contract.read.symbol(),
    ]);
    return new Token(chainId, address, Number(decimals), symbol);
  }

  async quoteNativeToken(chainId: number, addressIn: Address, amountIn: bigint): Promise<Quote> {
    const addressOut = WRAPPED_NATIVE_TOKEN_ADDRESS[chainId.toString()]!;
    return this.quote({
      chainId,
      amountIn,
      addressOut,
      addressIn
    });
  }

  async quote({ chainId, addressIn, addressOut, amountIn }: UniswapQuote): Promise<Quote> {
    const tokenIn = await this.getTokenInfo(chainId, addressIn as Address);
    const tokenOut = await this.getTokenInfo(chainId, addressOut as Address);
    const client = web3Provider.client(chainId);

    const quoterContract = getContract({
      address: QUOTER_CONTRACT_ADDRESS[chainId.toString()]!,
      abi: QuoterV2ABI.abi,
      client
    });

    const factoryAddress = UNISWAP_V3_FACTORY_ADDRESS[chainId.toString()];
    if (!factoryAddress) {
      throw RelayerError.unknown(`No Uniswap V3 factory address configured for chain ${chainId}`);
    }

    const factoryContract = getContract({
      address: factoryAddress,
      abi: [{
        type: 'function',
        name: 'getPool',
        stateMutability: 'view',
        inputs: [
          { name: 'tokenA', type: 'address' },
          { name: 'tokenB', type: 'address' },
          { name: 'fee', type: 'uint24' }
        ],
        outputs: [
          { name: 'pool', type: 'address' }
        ]
      }],
      client
    });

    const feeTiers: FeeAmount[] = [
      FeeAmount.LOWEST,
      FeeAmount.LOW_200,
      FeeAmount.LOW_300,
      FeeAmount.LOW_400,
      FeeAmount.LOW,
      FeeAmount.MEDIUM,
      FeeAmount.HIGH,
    ];

    for (const fee of feeTiers) {
      const pool = await factoryContract.read.getPool([
        addressIn as Address,
        addressOut as Address,
        fee,
      ]);

      if (pool !== '0x0000000000000000000000000000000000000000') {
        try {
          const quotedAmountOut = await quoterContract.simulate.quoteExactInputSingle([{
            tokenIn: tokenIn.address as Address,
            tokenOut: tokenOut.address as Address,
            fee,
            amountIn,
            sqrtPriceLimitX96: 0n,
          }]);

          const [amountOut] = quotedAmountOut.result;

          return {
            in: {
              amount: amountIn,
              decimals: tokenIn.decimals
            },
            out: {
              amount: amountOut,
              decimals: tokenOut.decimals
            }
          };
        } catch (error) {
          continue; // try next fee
        }
      }
    }

    throw RelayerError.unknown(
      `No usable Uniswap V3 pool found for pair ${tokenIn.symbol}/${tokenOut.symbol} on any known fee tier`
    );
  }
}
