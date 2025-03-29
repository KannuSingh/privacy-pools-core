type UniswapQuote = {
  chainId: number;
  inToken: string;
  outToken: string;
  inAmount: bigint;
};

export class UniswapService {
  async quote({ chainId, inToken, outToken, inAmount }: UniswapQuote) {
  }
}
