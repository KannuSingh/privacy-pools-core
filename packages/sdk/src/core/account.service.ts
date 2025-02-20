import { poseidon } from "maci-crypto/build/ts/hashing.js";
import { Hash, Secret } from "../types/index.js";
import { Hex } from "viem";
import { generatePrivateKey } from "viem/accounts";

interface DepositEvent {
  depositor: string;
  value: bigint;
  commitment: Hash;
  label: Hash;
  precommitment: Hash;
}

interface WithdrawalEvent {
  withdrawn: bigint;
  spentNullifier: Hash;
  newCommitment: Hash;
}

interface PoolAccount {
  label: Hash;
  deposit: Commitment;
  children: Commitment[];
}

interface Commitment {
  hash: Hash;
  value: bigint;
  label: Hash;
  nullifier: bigint;
  secret: bigint;
}

interface PrivacyPoolAccount {
  masterKeys: [Secret, Secret];
  poolAccounts: Map<bigint, PoolAccount[]>;
}

/**
 * Service responsible for handling commitment-related operations.
 * All hash operations use Poseidon for ZK-friendly hashing.
 */
export class AccountService {
  private account: PrivacyPoolAccount;
  private dataProvider?: any;

  constructor(account?: PrivacyPoolAccount, seed?: Hex) {
    this.account = account || this._initializeAccount(seed);
  }

  private _initializeAccount(seed?: Hex): PrivacyPoolAccount {
    let preimage = seed
      ? poseidon([BigInt(seed)])
      : BigInt(generatePrivateKey());

    let masterKey1 = poseidon([preimage, BigInt(1)]) as Secret;
    let masterKey2 = poseidon([preimage, BigInt(2)]) as Secret;

    return {
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

  private async _getEventsByScope(
    _: Hash[],
  ): Promise<
    Map<bigint, { deposits: DepositEvent[]; withdrawals: WithdrawalEvent[] }>
  > {
    let mappedScopes: Map<
      bigint,
      { deposits: DepositEvent[]; withdrawals: WithdrawalEvent[] }
    > = new Map();

    return mappedScopes;
  }

  private _log(sub: string, message: string): void {
    console.log(`${new Date().toISOString()} [Account::${sub}] ${message}`);
  }

  public getSpendableCommitments(
    privacyPoolAccount: PrivacyPoolAccount,
  ): Map<bigint, Commitment[]> {
    const result = new Map<bigint, Commitment[]>();

    // Iterate through each scope and its pool accounts
    for (const [scope, accounts] of privacyPoolAccount.poolAccounts.entries()) {
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

  public async retrieveHistory(scopes: Hash[]): Promise<void> {
    this._log("Recovery", "Fetching events for provided scopes");
    let mappedScopes = await this._getEventsByScope(scopes);
    this._log("Recovery", `Fetched events for ${mappedScopes.size} scopes`);

    // Discover pool accounts (deposits)
    for (const scope of scopes) {
      this._log(
        "Recovery",
        `Starting discovery of Pool Accounts for scope ${scope}`,
      );
      let index = BigInt(0);

      // Loop starting at index 0
      while (true) {
        // Compute deposit precommitment
        let nullifier = this._genDepositNullifier(scope, index);
        let secret = this._genDepositSecret(scope, index);
        let precommitment = this._hashPrecommitment(nullifier, secret);

        // Find Deposit with that precommiemtn
        let deposit = mappedScopes
          .get(scope)!
          .deposits.find((deposit) => deposit.precommitment == precommitment);

        // If not found, break loop.
        if (!deposit) break;

        this._log("Recovery", `Found Pool Account with index ${index}`);

        // If found, store as Pool Account and continue with next index.
        this.account.poolAccounts.get(scope)!.push({
          label: deposit.label,
          deposit: {
            hash: deposit.commitment,
            value: deposit.value,
            label: deposit.label,
            nullifier,
            secret,
          },
          children: [],
        });

        ++index;
      }

      // Check if accounts were found.
      let accounts = this.account.poolAccounts.get(scope);
      if (!accounts) {
        this._log("Recovery", `No Pool Accounts were found for scope ${scope}`);
        return;
      }

      // For each account = deposit
      for (const account of accounts) {
        this._log(
          "Recovery",
          `Starting discovery of withdrawals for Pool Account ${account.label}`,
        );
        // Define starting index
        let index = BigInt(0);
        // Define starting parent = deposit
        let parentCommitment = account.deposit;

        // Start with index 0 (first withdrawal)
        while (true) {
          // Compute child nullifier
          let childNullifier = this._genWithdrawalNullifier(
            parentCommitment.label,
            index,
          );
          // Compute child nullifier hash
          let nullifierHash = poseidon([childNullifier]);

          // Find Withdrawal with this spent nullifier hash
          let withdrawal = mappedScopes
            .get(scope)!
            .withdrawals.find(
              (withdrawal) => withdrawal.spentNullifier == nullifierHash,
            );

          // If not found, break.
          if (!withdrawal) {
            this._log(
              "Recovery",
              `No withdrawals found for Pool Account ${account.label}`,
            );
            break;
          }

          this._log(
            "Recovery",
            `Found withdrawal for ${withdrawal.withdrawn} value`,
          );
          // Compute child secret
          let childSecret = this._genWithdrawalSecret(
            parentCommitment.label,
            index,
          );
          // Compute child precommitment
          let childPrecommitment = this._hashPrecommitment(
            childNullifier,
            childSecret,
          );

          // Compute remaining value = previous commitment value - withdrawn value
          const remaining = parentCommitment.value - withdrawal.withdrawn;
          // Hash child commitment

          let commitment = {
            hash: this._hashCommitment(
              remaining,
              parentCommitment.label,
              childPrecommitment,
            ),
            value: remaining,
            label: parentCommitment.label,
            nullifier: childNullifier,
            secret: childSecret,
          };

          // Store child in account
          account.children.push(commitment);

          // Increase index, update the intermediate parent and continue
          ++index;
          parentCommitment = commitment;
        }
      }
    }
  }
}
