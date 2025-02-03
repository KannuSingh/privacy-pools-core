# Privacy Pool State Variables

The Privacy Pool contract maintains several critical state variables that are essential for its operation. These variables are defined across the `PrivacyPool` contract and its parent `State` contract. Here's an overview of the key state variables and their roles:

## Core Protocol Variables

| Variable              | Type          | Description                                                                                        |
| --------------------- | ------------- | -------------------------------------------------------------------------------------------------- |
| `SCOPE`               | `uint256`     | A unique identifier for the pool, computed from the contract address, chain ID, and asset address. |
| `ASSET`               | `address`     | The address of the asset (token) managed by this pool.                                             |
| `ENTRYPOINT`          | `IEntrypoint` | The address of the Entrypoint contract, which manages multiple pools.                              |
| `WITHDRAWAL_VERIFIER` | `IVerifier`   | The address of the Groth16 verifier for withdrawal proofs.                                         |
| `RAGEQUIT_VERIFIER`   | `IVerifier`   | The address of the Groth16 verifier for ragequit proofs.                                           |

## State Management Variables

| Variable           | Type                          | Description                                                                                         |
| ------------------ | ----------------------------- | --------------------------------------------------------------------------------------------------- |
| `nonce`            | `uint256`                     | A counter used to generate unique labels for deposits.                                              |
| `dead`             | `bool`                        | A flag indicating whether the pool is active (`false`) or has been irreversibly suspended (`true`). |
| `roots`            | `mapping(uint256 => uint256)` | Stores historical Merkle tree roots, indexed by their position.                                     |
| `currentRootIndex` | `uint32`                      | The index of the current (most recent) Merkle tree root.                                            |
| `_merkleTree`      | `LeanIMTData`                 | The internal Lean Incremental Merkle Tree data structure.                                           |
| `nullifierHashes`  | `mapping(uint256 => bool)`    | Tracks spent nullifiers to prevent double-spending.                                                 |
| `deposits`         | `mapping(uint256 => Deposit)` | Associates deposit labels with their corresponding deposit information.                             |

## Constants

| Constant            | Type     | Value     | Description                                                          |
| ------------------- | -------- | --------- | -------------------------------------------------------------------- |
| `VERSION`           | `string` | `"0.1.0"` | The semantic version of the contract.                                |
| `ROOT_HISTORY_SIZE` | `uint32` | `30`      | The number of historical roots stored for Merkle proof verification. |

The `Deposit` struct, used in the `deposits` mapping, has the following structure:

```solidity
struct Deposit {
    address depositor;
    uint256 amount;
    uint256 whenRagequitteable;
}
```

These state variables work together to maintain the integrity and functionality of the Privacy Pool:

- The `SCOPE`, `ASSET`, and verifier addresses ensure that each pool is uniquely identified and associated with the correct asset and proof verification mechanisms.
- The `nonce` and Merkle tree-related variables (`roots`, `currentRootIndex`, `_merkleTree`) manage the state of deposits and withdrawals in a privacy-preserving manner.
- The `nullifierHashes` mapping prevents double-spending by tracking spent commitments.
- The `deposits` mapping associates deposit labels with their original depositors, amounts, and ragequit timelock expiration, enabling the ragequit functionality.
- The `dead` flag allows for irreversibly suspending deposits to the pool while still allowing withdrawals.

Understanding these state variables is crucial for comprehending the internal workings of the Privacy Pool and how it maintains user privacy while ensuring the integrity of deposits and withdrawals.
