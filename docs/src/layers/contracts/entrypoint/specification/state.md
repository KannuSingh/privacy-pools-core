# Entrypoint State Variables

## Access Control Constants

### Role Definitions

```solidity
bytes32 internal constant _OWNER_ROLE = 0x6270edb7c868f86fda4adedba75108201087268ea345934db8bad688e1feb91b;
bytes32 internal constant _ASP_POSTMAN = 0xfc84ade01695dae2ade01aa4226dc40bdceaf9d5dbd3bf8630b1dd5af195bbc5;
```

Role constants define critical access control mechanisms:

- `_OWNER_ROLE`: Highest-level administrative access
  - Controls protocol configuration
  - Manages pool registration and upgrades
- `_ASP_POSTMAN`: Restricted role for Association Set Provider updates
  - Authorized to update root merkle trees
  - Prevents unauthorized protocol state modifications

## Pool Management State

### Pool Mappings

```solidity
mapping(uint256 _scope => IPrivacyPool _pool) public scopeToPool;
```

Maps protocol-specific scopes to corresponding Privacy Pool contracts:

- Enables dynamic pool discovery
- Supports multiple asset-specific pools
- Provides flexibility in protocol architecture

### Asset Configuration

```solidity
mapping(IERC20 _asset => AssetConfig _config) public assetConfig;
```

Stores configuration for each supported asset:

- Tracks associated Privacy Pool contract
- Defines minimum deposit amounts
- Manages vetting fees for each asset type

## Association Set State

### Association Sets

```solidity
AssociationSetData[] public associationSets;
```

Maintains historical record of Association Set Provider (ASP) roots:

- Stores cryptographic roots
- Tracks IPFS hash of associated metadata
- Includes timestamp of each root update

### Structure of AssociationSetData

```solidity
struct AssociationSetData {
    uint256 root;        // Merkle root of the association set
    bytes32 ipfsHash;    // Hash referencing off-chain metadata
    uint256 timestamp;   // Time of root update
}
```

## Key Characteristics

- Immutable role constants ensure strict access control
- Flexible mapping-based design allows protocol extensibility
- Cryptographically secure state management
- Supports multiple asset types and pool configurations

## Security Considerations

- Role constants use deterministic hash generation
- Mappings prevent unauthorized pool or asset modifications
- Association set tracking provides verifiable protocol history
- Supports transparent, auditable protocol state changes

## Design Patterns

- Use of `mapping` for efficient lookup
- Append-only array for association set tracking
- Constant-time access to pool and asset configurations
- Separation of concerns between different protocol components
