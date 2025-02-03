# Entrypoint Interface Specification

## Overview

The Entrypoint contract serves as the central coordination mechanism for the Privacy Pool protocol, managing deposits, withdrawals, and pool configurations across different asset types.

## Key Design Principles

- Centralized management of privacy pool operations
- Role-based access control
- Support for both native and ERC20 assets
- Upgradeable proxy architecture
- Fee mechanism for deposits and withdrawals

## Initialization

### `initialize`

Initializes the Entrypoint contract with owner and postman roles.

```solidity
function initialize(address _owner, address _postman) external initializer
```

#### Parameters

| Name       | Type      | Description                                                                                           |
| ---------- | --------- | ----------------------------------------------------------------------------------------------------- |
| `_owner`   | `address` | Address granted the owner role, responsible for critical protocol management functions                |
| `_postman` | `address` | Address granted the ASP (Association Set Provider) postman role, able to update association set roots |

#### Access Control

- Can only be called once during contract initialization
- Requires both `_owner` and `_postman` to be non-zero addresses

## Association Set Management

### `updateRoot`

Updates the Association Set Provider (ASP) root, creating a new entry in the `associationSets` array.

```solidity
function updateRoot(
    uint256 _root,
    bytes32 _ipfsHash
) external onlyRole(ASP_POSTMAN) returns (uint256 _index)
```

#### Parameters

| Name        | Type      | Description                                                               |
| ----------- | --------- | ------------------------------------------------------------------------- |
| `_root`     | `uint256` | New Merkle tree root representing the latest state of the association set |
| `_ipfsHash` | `bytes32` | IPFS hash referencing additional metadata about the association set       |

#### Returns

- `_index`: The index of the newly added association set

#### Requirements

- Caller must have ASP_POSTMAN role
- `_root` must be non-zero
- `_ipfsHash` must be non-zero

## Deposit Methods

### Native Asset Deposit

```solidity
function deposit(
    uint256 _precommitment
) external payable returns (uint256 _commitment)
```

### ERC20 Token Deposit

```solidity
function deposit(
    IERC20 _asset,
    uint256 _value,
    uint256 _precommitment
) external returns (uint256 _commitment)
```

#### Common Deposit Features

- Validates minimum deposit amount
- Deducts vetting fees
- Generates commitment hash
- Forwards funds to appropriate Privacy Pool

## Withdrawal Relay

### `relay`

Processes a withdrawal through a relayer, supporting complex fee and routing logic.

```solidity
function relay(
    IPrivacyPool.Withdrawal calldata _withdrawal,
    ProofLib.WithdrawProof calldata _proof
) external nonReentrant
```

#### Key Operations

- Verifies withdrawal proof
- Distributes funds to recipient
- Manages relay fees
- Prevents reentrancy attacks

## Pool Management Functions

### Pool Registration and Configuration

| Function                  | Purpose                                | Access Control  |
| ------------------------- | -------------------------------------- | --------------- |
| `registerPool`            | Add new Privacy Pool for an asset      | Owner Role Only |
| `removePool`              | Remove existing Privacy Pool           | Owner Role Only |
| `updatePoolConfiguration` | Modify pool deposit and fee parameters | Owner Role Only |
| `windDownPool`            | Irreversibly halt a pool's deposits    | Owner Role Only |

## View Functions

### Mappings and Arrays

| Name              | Type                               | Description                              |
| ----------------- | ---------------------------------- | ---------------------------------------- |
| `scopeToPool`     | `mapping(uint256 => IPrivacyPool)` | Maps unique pool scope to pool contract  |
| `assetConfig`     | `mapping(IERC20 => AssetConfig)`   | Stores configuration for each asset pool |
| `associationSets` | `AssociationSetData[]`             | Historical record of ASP roots           |

## Security Considerations

- Role-based access control prevents unauthorized actions
- Non-reentrant withdrawal relay
- Minimum deposit and fee mechanisms
- Upgradeable contract design

## Performance Characteristics

- O(1) pool lookup via mappings
- Constant-time deposit and withdrawal processing
- Flexible fee and routing mechanisms
