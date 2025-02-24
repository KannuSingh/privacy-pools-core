import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { Hash, Secret } from "../types/commitment.js";
import { Hex, bytesToNumber } from "viem";
import { english, generateMnemonic, mnemonicToAccount } from "viem/accounts";
import { DataService } from "./data.service.js";
import {
  Commitment,
  PoolAccount,
  PoolInfo,
  PrivacyPoolAccount,
} from "../types/account.js";

export class AccountService {
  account: PrivacyPoolAccount;

  constructor(
    private readonly dataService: DataService,
    account?: PrivacyPoolAccount,
    mnemonic?: string,
  ) {
    this.account = account || this._initializeAccount(mnemonic);
  }

  private _initializeAccount(mnemonic?: string): PrivacyPoolAccount {
    mnemonic = mnemonic || generateMnemonic(english, 128);

    console.log("mnemonic: ", mnemonic);

    let key1 = bytesToNumber(
      mnemonicToAccount(mnemonic, { accountIndex: 0 }).getHdKey().privateKey!,
    );

    let key2 = bytesToNumber(
      mnemonicToAccount(mnemonic, { accountIndex: 1 }).getHdKey().privateKey!,
    );

    let masterKey1 = poseidon([BigInt(key1)]) as Secret;
    let masterKey2 = poseidon([BigInt(key2)]) as Secret;

    return {
      mnemonic,
      masterKeys: [masterKey1, masterKey2],
      poolAccounts: new Map(),
    };
  }

  private _genDepositNullifier(scope: Hash, index: bigint): Secret {
    return poseidon([this.account.masterKeys[0], scope, index]) as Secret;
  }

  private _genDepositSecret(scope: Hash, index: bigint): Secret {
    return poseidon([this.account.masterKeys[1], scope, index]) as Secret;
  }

  private _genWithdrawalNullifier(label: Hash, index: bigint): Secret {
    return poseidon([this.account.masterKeys[0], label, index]) as Secret;
  }

  private _genWithdrawalSecret(label: Hash, index: bigint): Secret {
    return poseidon([this.account.masterKeys[1], label, index]) as Secret;
  }

  private _hashCommitment(
    value: bigint,
    label: Hash,
    precommitment: Hash,
  ): Hash {
    return poseidon([value, label, precommitment]) as Hash;
  }

  private _hashPrecommitment(nullifier: Secret, secret: Secret): Hash {
    return poseidon([nullifier, secret]) as Hash;
  }

  private _log(sub: string, message: string): void {
    console.log(`${new Date().toISOString()} [Account::${sub}] ${message}`);
  }

  public getSpendableCommitments(): Map<bigint, Commitment[]> {
    const result = new Map<bigint, Commitment[]>();

    // Iterate through each scope and its pool accounts
    for (const [scope, accounts] of this.account.poolAccounts.entries()) {
      const nonZeroCommitments: Commitment[] = [];

      // Process each pool account in the current scope
      for (const account of accounts) {
        // Get the last commitment (either from children or deposit)
        const lastCommitment =
          account.children.length > 0
            ? account.children[account.children.length - 1]
            : account.deposit;

        // Check if the commitment has a non-zero value
        if (lastCommitment!.value !== BigInt(0)) {
          nonZeroCommitments.push(lastCommitment!);
        }
      }

      // Only add to result if there are non-zero commitments
      if (nonZeroCommitments.length > 0) {
        result.set(scope, nonZeroCommitments);
      }
    }
    return result;
  }

  /**
   * Creates nullifier and secret for a new deposit
   * @param scope The scope of the pool to deposit into
   * @returns The nullifier, secret, and precommitment for the deposit
   */
  public createDepositSecrets(
    scope: Hash,
    index?: bigint,
  ): {
    nullifier: Secret;
    secret: Secret;
    precommitment: Hash;
  } {
    // Find the next available index for this scope
    const accounts = this.account.poolAccounts.get(scope);
    index = index || BigInt(accounts?.length || 0);

    const nullifier = this._genDepositNullifier(scope, index);
    const secret = this._genDepositSecret(scope, index);
    const precommitment = this._hashPrecommitment(nullifier, secret);

    return { nullifier, secret, precommitment };
  }

  /**
   * Creates nullifier and secret for spending a commitment
   * @param commitment The commitment to spend
   * @returns The nullifier and secret for the new commitment
   */
  public createWithdrawalSecrets(commitment: Commitment): {
    nullifier: Secret;
    secret: Secret;
  } {
    // Find the account with this label
    let index: bigint | undefined;

    for (const accounts of this.account.poolAccounts.values()) {
      const account = accounts.find((acc) => acc.label === commitment.label);
      if (account) {
        // Use the next index after the last withdrawal
        index = BigInt(account.children.length);
        break;
      }
    }

    if (index === undefined) {
      throw new Error(
        `No account found for commitment with label ${commitment.label}`,
      );
    }

    const nullifier = this._genWithdrawalNullifier(commitment.label, index);
    const secret = this._genWithdrawalSecret(commitment.label, index);

    return { nullifier, secret };
  }

  /**
   * Adds a new pool account after depositing
   * @param scope The scope of the pool
   * @param value The deposit value
   * @param nullifier The nullifier used for the deposit
   * @param secret The secret used for the deposit
   * @param label The label for the commitment
   * @param blockNumber The block number of the deposit
   * @param txHash The transaction hash of the deposit
   * @returns The new pool account
   */
  public addPoolAccount(
    scope: Hash,
    value: bigint,
    nullifier: Secret,
    secret: Secret,
    label: Hash,
    blockNumber: bigint,
    txHash: Hash,
  ): PoolAccount {
    const precommitment = this._hashPrecommitment(nullifier, secret);
    const commitment = this._hashCommitment(value, label, precommitment);

    const newAccount: PoolAccount = {
      label,
      deposit: {
        hash: commitment,
        value,
        label,
        nullifier,
        secret,
        blockNumber,
        txHash,
      },
      children: [],
    };

    // Initialize the array for this scope if it doesn't exist
    if (!this.account.poolAccounts.has(scope)) {
      this.account.poolAccounts.set(scope, []);
    }

    // Add the new account
    this.account.poolAccounts.get(scope)!.push(newAccount);

    this._log(
      "Deposit",
      `Added new pool account with value ${value} and label ${label}`,
    );

    return newAccount;
  }

  /**
   * Adds a new commitment to the account after spending
   * @param parentCommitment The commitment that was spent
   * @param value The remaining value after spending
   * @param nullifier The nullifier used for spending
   * @param secret The secret used for spending
   * @returns The new commitment
   */
  public addWithdrawalCommitment(
    parentCommitment: Commitment,
    value: bigint,
    nullifier: Secret,
    secret: Secret,
    blockNumber: bigint,
    txHash: Hash,
  ): Commitment {
    // Find the account for this commitment
    let foundAccount: PoolAccount | undefined;
    let foundScope: bigint | undefined;

    for (const [scope, accounts] of this.account.poolAccounts.entries()) {
      foundAccount = accounts.find((account) => {
        // Check if this is the parent commitment
        if (account.deposit.hash === parentCommitment.hash) return true;
        // Check children
        return account.children.some(
          (child) => child.hash === parentCommitment.hash,
        );
      });

      if (foundAccount) {
        foundScope = scope;
        break;
      }
    }

    if (!foundAccount || !foundScope) {
      throw new Error(
        `No account found for commitment ${parentCommitment.hash}`,
      );
    }

    // Create the precommitment
    const precommitment = this._hashPrecommitment(nullifier, secret);

    // Create the new commitment
    const newCommitment: Commitment = {
      hash: this._hashCommitment(value, parentCommitment.label, precommitment),
      value,
      label: parentCommitment.label,
      nullifier,
      secret,
      blockNumber,
      txHash,
    };

    // Add to children
    foundAccount.children.push(newCommitment);

    this._log(
      "Commitment",
      `Added new commitment with value ${value} to account with label ${parentCommitment.label}`,
    );

    return newCommitment;
  }

  public async retrieveHistory(pools: PoolInfo[]): Promise<void> {
    this._log("Recovery", `Fetching events for ${pools.length} pools`);

    // Initialize pool accounts for each scope
    for (const pool of pools) {
      if (!this.account.poolAccounts.has(pool.scope)) {
        this.account.poolAccounts.set(pool.scope, []);
      }
    }

    // Process pools in parallel
    await Promise.all(
      pools.map(async (pool) => {
        this._log(
          "Recovery",
          `Processing pool ${pool.address} on chain ${pool.chainId} from block ${pool.deploymentBlock}`,
        );

        // First, get only deposit events
        const deposits = await this.dataService.getDeposits(pool.chainId, {
          fromBlock: pool.deploymentBlock,
        });

        this._log(
          "Recovery",
          `Found ${deposits.length} deposits for pool ${pool.address}`,
        );

        // Create a map for faster deposit lookups
        const depositMap = new Map<Hash, (typeof deposits)[0]>();
        for (const deposit of deposits) {
          depositMap.set(deposit.precommitment, deposit);
        }

        // Find all deposits for this pool
        const foundDeposits: Array<{
          index: bigint;
          nullifier: Secret;
          secret: Secret;
          deposit: (typeof deposits)[0];
        }> = [];

        // Try indices until we don't find any more deposits
        let index = BigInt(0);
        let firstDepositBlock: bigint | undefined;

        while (true) {
          const nullifier = this._genDepositNullifier(pool.scope, index);
          const secret = this._genDepositSecret(pool.scope, index);
          const precommitment = this._hashPrecommitment(nullifier, secret);

          const deposit = depositMap.get(precommitment);
          if (!deposit) break;

          // Track the first deposit block
          if (!firstDepositBlock || deposit.blockNumber < firstDepositBlock) {
            firstDepositBlock = deposit.blockNumber;
          }

          foundDeposits.push({ index, nullifier, secret, deposit });
          index++;
        }

        if (foundDeposits.length === 0) {
          this._log(
            "Recovery",
            `No Pool Accounts were found for scope ${pool.scope}`,
          );
          return;
        }

        this._log(
          "Recovery",
          `Found ${foundDeposits.length} deposits for pool ${pool.address}`,
        );

        // Get withdrawals only if we found deposits
        const withdrawals = await this.dataService.getWithdrawals(
          pool.chainId,
          {
            fromBlock: firstDepositBlock!,
          },
        );

        // Create a map for faster withdrawal lookups
        const withdrawalMap = new Map<Hash, (typeof withdrawals)[0]>();
        for (const withdrawal of withdrawals) {
          withdrawalMap.set(withdrawal.spentNullifier, withdrawal);
        }

        this._log(
          "Recovery",
          `Found ${withdrawals.length} withdrawals for pool ${pool.address}`,
        );

        // Process each found deposit
        const accounts = foundDeposits.map(({ nullifier, secret, deposit }) => {
          const account: PoolAccount = {
            label: deposit.label,
            deposit: {
              hash: deposit.commitment,
              value: deposit.value,
              label: deposit.label,
              nullifier,
              secret,
              blockNumber: deposit.blockNumber,
              txHash: deposit.transactionHash,
            },
            children: [],
          };

          // Find all withdrawals for this account
          let withdrawalIndex = BigInt(0);
          let parentCommitment = account.deposit;

          while (true) {
            const childNullifier = this._genWithdrawalNullifier(
              parentCommitment.label,
              withdrawalIndex,
            );
            const nullifierHash = poseidon([childNullifier]) as Hash;

            const withdrawal = withdrawalMap.get(nullifierHash);
            if (!withdrawal) break;

            const childSecret = this._genWithdrawalSecret(
              parentCommitment.label,
              withdrawalIndex,
            );
            const childPrecommitment = this._hashPrecommitment(
              childNullifier,
              childSecret,
            );

            const remaining = parentCommitment.value - withdrawal.withdrawn;

            const commitment = {
              hash: this._hashCommitment(
                remaining,
                parentCommitment.label,
                childPrecommitment,
              ),
              value: remaining,
              label: parentCommitment.label,
              nullifier: childNullifier,
              secret: childSecret,
              blockNumber: withdrawal.blockNumber,
              txHash: withdrawal.transactionHash,
            };

            account.children.push(commitment);
            parentCommitment = commitment;
            withdrawalIndex++;
          }

          return account;
        });

        // Store all accounts for this pool
        this.account.poolAccounts.set(pool.scope, accounts);
      }),
    );
  }
}
