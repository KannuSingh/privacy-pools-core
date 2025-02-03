# Entrypoint Data Structures

## Asset Configuration Structure

```solidity
struct AssetConfig {
    IPrivacyPool pool;
    uint256 minimumDepositAmount;
    uint256 vettingFeeBPS;
}
```

### Fields Breakdown

| Field                  | Description                                                 |
| ---------------------- | ----------------------------------------------------------- |
| `pool`                 | Reference to the Privacy Pool contract for a specific asset |
| `minimumDepositAmount` | Minimum amount required for deposits                        |
| `vettingFeeBPS`        | Vetting fee in basis points (0.01% increments)              |

### Usage Patterns

- Stores configuration for each supported asset
- Enables flexible pool and fee management
- Provides granular control over deposit requirements

## Association Set Data Structure

```solidity
struct AssociationSetData {
    uint256 root;
    bytes32 ipfsHash;
    uint256 timestamp;
}
```

### Fields Breakdown

| Field       | Description                                                       |
| ----------- | ----------------------------------------------------------------- |
| `root`      | Merkle root representing the Association Set Provider (ASP) state |
| `ipfsHash`  | Reference to off-chain metadata                                   |
| `timestamp` | Time of root update                                               |

### Usage Patterns

- Tracks historical protocol state roots
- Provides verifiable, append-only record of ASP updates
- Supports off-chain data referencing

## Fee Data Structure

```solidity
struct FeeData {
    address recipient;
    address feeRecipient;
    uint256 relayFeeBPS;
}
```

### Fields Breakdown

| Field          | Description                                    |
| -------------- | ---------------------------------------------- |
| `recipient`    | Address receiving the primary withdrawal funds |
| `feeRecipient` | Address receiving relay fees                   |
| `relayFeeBPS`  | Relay fee in basis points                      |

### Usage Patterns

- Manages fee distribution for relayed withdrawals
- Separates primary recipient and fee recipient
- Enables flexible fee calculation

## Withdrawal Data Structure

```solidity
struct Withdrawal {
    address processooor;
    uint256 scope;
    bytes data;
}
```

### Fields Breakdown

| Field         | Description                                       |
| ------------- | ------------------------------------------------- |
| `processooor` | Address authorized to process the withdrawal      |
| `scope`       | Unique identifier for the specific privacy pool   |
| `data`        | Additional encoded data for withdrawal processing |

### Usage Patterns

- Defines withdrawal authorization parameters
- Supports cross-pool withdrawal mechanisms
- Provides flexible additional data encoding

## Design Principles

- Modular structure for easy extension
- Clear separation of concerns
- Minimal storage overhead
- Cryptographically secure parameter handling

## Security Considerations

- Immutable structure definitions
- Strict type safety
- Prevents unauthorized modifications
- Supports complex protocol interactions with minimal complexity

## Architectural Flexibility

These data structures enable:

- Multi-asset support
- Dynamic fee mechanisms
- Verifiable protocol state
- Extensible withdrawal processing

## Performance Characteristics

- Constant-time access to configuration
- Minimal gas overhead
- Efficient state management
- Supports complex protocol logic with lightweight structures
