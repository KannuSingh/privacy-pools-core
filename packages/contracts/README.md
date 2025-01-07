# Privacy Pool Contracts

This package contains the smart contract implementations for the Privacy Pool protocol, built using Foundry. The contracts enable private asset transfers through a system of deposits and zero-knowledge withdrawals with built-in compliance mechanisms.

## Protocol Overview

The protocol enables users to deposit assets publicly and withdraw them privately, provided they can prove membership in an approved set of addresses. Each supported asset (native or ERC20) has its own dedicated pool contract that inherits from a common `PrivacyPool` implementation.

### Deposit Flow

When a user deposits funds, they:

1. Generate commitment parameters (nullifier and secret)
2. Send the deposit transaction through the Entrypoint
3. The Entrypoint routes the deposit to the appropriate pool
4. The pool records the commitment in its state tree
5. The depositor receives a deposit identifier (label) and a commitment hash

### Withdrawal Flow

To withdraw funds privately, users:

1. Generate a zero-knowledge proof demonstrating:
   - Ownership of a valid deposit commitment
   - Membership in the approved address set
   - Correctness of the withdrawal amount
2. Submit the withdrawal transaction through a relayer
3. The pool verifies the proof and processes the withdrawal
4. A new commitment is created for the remaining funds (even if it is zero)

### Emergency Exit (`ragequit`) 

The protocol implements a ragequit mechanism that allows original depositors to withdraw their funds directly in case of emergency. This process:

1. Requires the original deposit label
2. Reveals the nullifier and secret
3. Bypasses the approved address set verification
4. Can only be executed by the original depositor
5. Withdraws the full deposit amount

## Contract Architecture

### Core Contracts

**`State.sol`**
The base contract implementing fundamental state management:

- Manages the Merkle tree state using LeanIMT
- Tracks tree roots with a sliding window (30 latest roots)
- Records used nullifiers to prevent double spending
- Maps deposit labels to original depositors
- Implements tree operations

**`PrivacyPool.sol`**
An abstract contract inheriting from State.sol that implements the core protocol logic:

Standard Operations:

- Deposit processing (through Entrypoint only)
- Withdrawal verification and processing
- Wind down mechanism for pool deprecation
- Ragequit mechanism for non-approved withdrawals
- Abstract methods for asset transfers

### Pool Implementations

**`PrivacyPoolSimple.sol`**
Implements `PrivacyPool` for native asset:

- Handles native asset deposits through `payable` functions
- Implements native asset transfer logic
- Validates transaction values

**`PrivacyPoolComplex.sol`**
Implements `PrivacyPool` for ERC20 tokens:

- Manages token approvals and transfers
- Implements safe ERC20 operations

### Protocol Coordination

**`Entrypoint.sol`**
Manages protocol-wide operations:

- Routes deposits to appropriate pools
- Maintains the approved address set (ASP)
- Processes withdrawal relays
- Handles fee collection and distribution
- Manages pool registration and removal
- Controls protocol upgrades and access control

### Supporting Libraries

**`ProofLib.sol`**
Handles accessing a proof signals values.

**`Poseidon.sol`**
Poseidon hashers generated using `circomlibjs`.

## Development

### Prerequisites

- Foundry
- Node.js 20+
- Yarn

### Building

```bash
# Compile contracts
yarn build
```

### Testing

```bash
# Run contract tests
yarn test
```