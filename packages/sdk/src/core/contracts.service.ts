import {
  Abi,
  Account,
  Address,
  Chain,
  Hex,
  PublicClient,
  WalletClient,
  createPublicClient,
  createWalletClient,
  getAddress,
  http,
} from "viem";
import { Withdrawal, WithdrawalProof } from "../types/withdrawal.js";
import {
  ContractInteractions,
  TransactionResponse,
} from "../interfaces/contracts.interface.js";
import { IEntrypointABI } from "../abi/IEntrypoint.js";
import { IPrivacyPoolABI } from "../abi/IPrivacyPool.js";
import { privateKeyToAccount } from "viem/accounts";
import { CommitmentProof } from "../types/commitment.js";
import { bigintToHex } from "../crypto.js";

export class ContractInteractionsService implements ContractInteractions {
  private publicClient: PublicClient;
  private walletClient: WalletClient;
  private entrypointAddress: Address;
  private account: Account;

  constructor(
    rpcUrl: string,
    chain: Chain,
    entrypointAddress: Address,
    accountPrivateKey: Hex,
  ) {
    if (!entrypointAddress) {
      throw new Error(
        "Invalid entrypoint addresses provided to ContractInteractionsService",
      );
    }

    this.account = privateKeyToAccount(accountPrivateKey);

    this.walletClient = createWalletClient({
      chain: chain,
      transport: http(rpcUrl),
      account: this.account,
    });

    this.publicClient = createPublicClient({
      chain: chain,
      transport: http(rpcUrl),
    });

    this.entrypointAddress = entrypointAddress;
  }

  async depositERC20(
    asset: Address,
    amount: bigint,
    precommitment: bigint,
  ): Promise<TransactionResponse> {
    try {
      const { request } = await this.publicClient.simulateContract({
        address: this.entrypointAddress,
        abi: IEntrypointABI as Abi,
        functionName: "deposit",
        args: [asset, amount, precommitment],
        value: 0n,
        account: this.account,
      });
      return await this.executeTransaction(request);
    } catch (error) {
      console.error("Deposit ERC20 Error:", { error, asset, amount });
      throw new Error(
        `Failed to deposit ERC20: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }

  async depositETH(
    amount: bigint,
    precommitment: bigint,
  ): Promise<TransactionResponse> {
    try {
      const { request } = await this.publicClient.simulateContract({
        address: this.entrypointAddress,
        abi: IEntrypointABI as Abi,
        functionName: "deposit",
        args: [precommitment],
        value: amount,
        account: this.account,
      });

      return await this.executeTransaction(request);
    } catch (error) {
      console.error("Deposit ETH Error:", { error, amount });
      throw new Error(
        `Failed to deposit ETH: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }

  async withdraw(
    withdrawal: Withdrawal,
    withdrawalProof: WithdrawalProof,
  ): Promise<TransactionResponse> {
    try {
      const formattedProof = this.formatProof(withdrawalProof);

      // get pool address from scope
      const scopeData = await this.getScopeData(withdrawal.scope);

      const { request } = await this.publicClient.simulateContract({
        address: scopeData.poolAddress,
        abi: IPrivacyPoolABI as Abi,
        functionName: "withdraw",
        account: this.account.address as Address,
        args: [withdrawal, formattedProof],
      });

      return await this.executeTransaction(request);
    } catch (error) {
      console.error("Withdraw Error Details:", {
        error,
        accountAddress: this.account.address,
      });
      throw new Error(
        `Failed to Withdraw: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }

  async relay(
    withdrawal: Withdrawal,
    withdrawalProof: WithdrawalProof,
  ): Promise<TransactionResponse> {
    try {
      const formattedProof = this.formatProof(withdrawalProof);

      const { request } = await this.publicClient.simulateContract({
        address: this.entrypointAddress,
        abi: [...IEntrypointABI as Abi, ...IPrivacyPoolABI as Abi],
        functionName: "relay",
        account: this.account.address as Address,
        args: [withdrawal, formattedProof]
      });

      return await this.executeTransaction(request);
    } catch (error) {
      console.error("Withdraw Error Details:", {
        error,
        scope: withdrawal.scope,
        accountAddress: this.account.address,
      });
      throw error;
    }
  }

  async ragequit(
    commitmentProof: CommitmentProof,
    privacyPoolAddress: Address,
  ): Promise<TransactionResponse> {
    try {
      const formattedProof = this.formatProof(commitmentProof);

      const { request } = await this.publicClient.simulateContract({
        address: privacyPoolAddress,
        abi: IPrivacyPoolABI as Abi,
        functionName: "ragequit",
        args: [formattedProof],
        account: this.account,
      });

      return await this.executeTransaction(request);
    } catch (error) {
      console.error("Ragequit Error:", { error });
      throw new Error(
        `Failed to Ragequit: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }

  async getScope(privacyPoolAddress: Address): Promise<bigint> {
    const scope = await this.publicClient.readContract({
      address: privacyPoolAddress,
      abi: IPrivacyPoolABI as Abi,
      functionName: "SCOPE",
      account: this.account,
    });

    return BigInt(scope as string);
  }

  async getStateRoot(privacyPoolAddress: Address): Promise<bigint> {
    const stateRoot = await this.publicClient.readContract({
      address: privacyPoolAddress,
      abi: IEntrypointABI as Abi,
      account: this.account,
      functionName: "latestRoot",
    });

    return BigInt(stateRoot as string);
  }

  async getStateSize(privacyPoolAddress: Address): Promise<bigint> {
    const stateSize = await this.publicClient.readContract({
      address: privacyPoolAddress,
      abi: IPrivacyPoolABI as Abi,
      account: this.account,
      // this should be added in the next update of PrivacyPoolSimple.sol
      functionName: "currentTreeSize",
    });

    return BigInt(stateSize as string);
  }

  async getScopeData(scope: bigint): Promise<{ poolAddress: Address; assetAddress: Address }> {
    try {
      // get pool address fro entrypoint
      const poolAddress = await this.publicClient.readContract({
        address: this.entrypointAddress,
        abi: IEntrypointABI as Abi,
        account: this.account,
        args: [scope],
        functionName: "scopeToPool",
      });

      // if no pool throw error 
      if (!poolAddress || poolAddress === "0x0000000000000000000000000000000000000000") {
        throw new Error(`No pool found for scope ${scope.toString()}`);
      }

      // get asset adress from pool 
      const assetAddress = await this.publicClient.readContract({
        address: getAddress(poolAddress as string),
        abi: IPrivacyPoolABI as Abi,
        account: this.account,
        functionName: "ASSET",
      });

      return { poolAddress: getAddress(poolAddress as string), assetAddress: getAddress(assetAddress as string) };
    } catch (error) {
      console.error(`Error resolving scope ${scope.toString()}:`, error);
      throw new Error(`Failed to resolve scope ${scope.toString()}: ${error instanceof Error ? error.message : "Unknown error"}`);
    }
  }

  private formatProof(proof: CommitmentProof | WithdrawalProof) {
    return {
      pA: [
        bigintToHex(proof.proof.pi_a?.[0]),
        bigintToHex(proof.proof.pi_a?.[1]),
      ],
      pB: [
        [
          bigintToHex(proof.proof.pi_b?.[0]?.[1]),
          bigintToHex(proof.proof.pi_b?.[0]?.[0]),
        ],
        [
          bigintToHex(proof.proof.pi_b?.[1]?.[1]),
          bigintToHex(proof.proof.pi_b?.[1]?.[0]),
        ],
      ],
      pC: [
        bigintToHex(proof.proof.pi_c?.[0]),
        bigintToHex(proof.proof.pi_c?.[1]),
      ],
      pubSignals: proof.publicSignals.map(bigintToHex),
    };
  }

  private async executeTransaction(request: any): Promise<TransactionResponse> {
    try {
      const hash = await this.walletClient.writeContract(request);
      return {
        hash,
        wait: async () => {
          await this.publicClient.waitForTransactionReceipt({ hash });
        },
      };
    } catch (error) {
      console.error("Transaction Execution Error:", { error, request });
      throw new Error(
        `Transaction failed: ${error instanceof Error ? error.message : "Unknown error"}`,
      );
    }
  }
}
