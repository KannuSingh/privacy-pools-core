# Privacy Pool Interface Specification

[OVERVIEW: Overview of the Privacy Pool contract's public interface]

## Constants

### SCOPE

```solidity
uint256 public immutable SCOPE
```

[SCOPE_DESC: Scope constant description]

### ASSET

```solidity
IERC20 public immutable ASSET
```

[ASSET_DESC: Asset constant description]

## Core Operations

### deposit

```solidity
function deposit(
    uint256 _commitment
) external payable
```

[DEPOSIT_DESC: Deposit functionality]

### withdraw

```solidity
function withdraw(
    Withdrawal calldata _withdrawal,
    WithdrawProof calldata _proof
) external
```

[WITHDRAW_DESC: Withdrawal functionality]

### ragequit

```solidity
function ragequit(
    RagequitProof calldata _proof
) external
```

[RAGEQUIT_DESC: Ragequit functionality]

## Administrative Functions

### windDown

```solidity
function windDown() external
```

[WIND_DOWN_DESC: Wind down process]
