# Commitments

## Overview

A commitment in the Privacy Pool protocol is a cryptographic representation of some value owned by some user in a pool.

## Commitment Structure

### Components

A commitment consists of four primary components:

1. **Value**: The amount of value
2. **Label**: A unique identifier generated from the pool's scope and nonce when depositing
3. **Nullifier**: A unique, random secret value that prevents double-spending
4. **Secret**: A random secret value to prevent nullifier hash pre-image attacks.

### Mathematical Representation

Let the commitment be represented by the function:

$$\text{Commitment} = \text{Hash}(value, \text{label}, \text{precommitment})$$

Where:

- $\text{precommitment} = \text{Hash}(\text{nullifier}, \text{secret})$

## Security Properties

- Achieved through the use of Poseidon hash function
- Ensures the commitment cannot be modified without knowing the original secrets
- The commitment hash reveals no information about the original values

## Usage in Protocol

### In Deposits

- Generated when a user deposits funds
- Stored in the state merkle tree
- Used to track fund ownership without revealing details

### In Withdrawals

- Allows partial or full withdrawal of funds
- Generates a new commitment representing remaining balance
- Prevents double-spending through nullifier mechanism

### In Ragequit

- Enables fund recovery if label is not included in Association Set Provider (ASP)
- Allows original depositor to withdraw funds directly

## Implementation Details

### Parameter Selection

- Nullifier and secret generated randomly
- Constrained to the Snark scalar field to ensure compatibility with zero-knowledge circuits

## Security Considerations

- Always generate nullifiers and secrets using cryptographically secure random methods
- Protect the nullifier and secret to prevent unauthorized withdrawals
