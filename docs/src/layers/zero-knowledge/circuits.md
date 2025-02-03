# Circuits

## Overview

Zero-knowledge circuits form the cryptographic backbone of the Privacy Pool protocol, enabling private, verifiable financial transactions without revealing sensitive information. These circuits leverage advanced cryptographic techniques to:

- **Preserve Privacy**: Conceal transaction details while proving their validity
- **Ensure Integrity**: Cryptographically verify fund ownership and transfers
- **Prevent Double-Spending**: Create unique, non-reusable transaction proofs

### Core Circuits

The protocol implements three primary zero-knowledge circuits:

1. **Commitment Circuit**:

   - Generates cryptographic commitments
   - Converts deposit information into private, verifiable representations

2. **Withdrawal Circuit**:

   - Enables private fund withdrawals
   - Proves ownership and validates withdrawal conditions
   - Creates new commitments representing remaining funds

### Technical Foundation

- **Proof System**: Groth16
- **Hash Function**: Poseidon
- **Merkle Tree**: Lean Incremental Merkle Tree (LeanIMT)
- **Field**: Snark scalar field
- **Curve**: bn128

### Key Properties

- **Zero-Knowledge**: No original transaction details are revealed
- **Non-Interactive**: Proofs can be verified without additional communication
- **Succinct**: Compact proof sizes
- **Cryptographically Secure**: Mathematically rigorous validation

These circuits represent a sophisticated approach to blockchain privacy, allowing users to transact with unprecedented confidentiality and security.
