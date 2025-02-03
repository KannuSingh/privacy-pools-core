# Privacy Pool Protocol Overview

Privacy Pool is a zero-knowledge protocol that enables private withdrawals of assets through validation by an Association Set Provider (ASP). The system uses an optimized incremental Merkle tree implementation and zero-knowledge proofs to maintain privacy while ensuring security.

## Key Features

### Privacy Protection

- Deposits create initially public commitments that can be spent through zero-knowledge proofs
- State transitions managed through LeanIMT (Lean Incremental Merkle Tree) optimized for gas efficiency
- Nullifier system prevents double-spending while maintaining privacy
- Optional relayer support for withdrawal processing

### Asset Support

- Native assets through `PrivacyPoolSimple` implementation
- ERC20 tokens through `PrivacyPoolComplex` implementation
- Configurable deposit minimums and protocol fees per asset
- Support for both full and partial withdrawals

### Security Guarantees

- Non-custodial design with atomic operations only
- Deposit suspension capabilities through `windDown` mechanism
- Direct withdrawal option (`ragequit`) for unapproved depositors
- Groth16 proof verification for ragequits and withdrawals
- ASP tree validation for withdrawal compliance

## Getting started

### For Users

[USER_GUIDE: Basic user guide]

### For Developers

[DEV_GUIDE: Integration overview]

### For Operators

[OPERATOR_GUIDE: Operation overview]

## Contributions
