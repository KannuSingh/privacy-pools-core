# Privacy Pool Data Structures

[OVERVIEW: Overview of key data structures used in the Privacy Pool contract]

## Withdrawal Structure

### Withdrawal Data

```solidity
struct Withdrawal {
    address processooor;
    uint256 scope;
    bytes data;
}
```

#### Fields

| Field         | Type      | Description                         |
| ------------- | --------- | ----------------------------------- |
| `scope`       | `uint256` | [SCOPE_DESC: Pool scope]            |
| `processooor` | `address` | [PROCESSOR_DESC: Processor address] |
| `data`        | `bytes`   | [DATA_DESC: Additional data]        |

#### Usage

[WITHDRAWAL_USAGE: How this structure is used]

## Proof Structures

### Withdrawal Proof

```solidity
struct WithdrawProof {
    uint256[] ;
    uint256[] proof;
}
```

#### Fields

| Field | Type | Description |
| ----- | ---- | ----------- |

#### Usage

[PROOF_USAGE: How proofs are used]

## Proof Verification

### Public Inputs

```solidity
[PUBLIC_INPUTS: Input structure]
```

[INPUT_DESC: Input validation]

### Proof Format

```solidity
[PROOF_FORMAT: Proof structure]
```

[FORMAT_DESC: Format validation]
