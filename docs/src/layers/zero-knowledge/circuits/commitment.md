# Commitment Circuit

## Overview

The `CommitmentHasher` circuit is a fundamental zero-knowledge circuit responsible for proving ownership of commitments.

## Circuit Design

### High-Level Architecture

The circuit implements a hash-based commitment generation process using the Poseidon hash function. It takes private inputs representing a commitment's components and generates public outputs that can be verified without revealing the original private inputs.

## Circuit Parameters

### Inputs

| Name        | Description                                         |
| ----------- | --------------------------------------------------- |
| `value`     | Value of the commitment                             |
| `label`     | Label associated with the commitment                |
| `nullifier` | Secret unique identifier to prevent double-spending |
| `secret`    | Random secret                                       |

### Outputs

| Name                | Description                   |
| ------------------- | ----------------------------- |
| `commitment`        | Hash of the entire commitment |
| `precommitmentHash` | Hash of nullifier and secret  |
| `nullifierHash`     | Hash of the nullifier         |

## Circuit Logic

### Main Component: CommitmentHasher

The circuit follows a three-step hash generation process:

1. **Nullifier Hash Generation**

   - Takes the nullifier as input
   - Computes a unique hash to prevent double-spending (verified at smart contract layer)

2. **Precommitment Hash Generation**

   - Combines nullifier and secret
   - Creates an intermediate hash representing the commitment's private components

3. **Final Commitment Hash**
   - Combines value, label, and precommitment hash
   - Generates the final commitment hash
