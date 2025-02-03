# Withdrawal Circuit

## Overview

The Withdrawal Circuit is a critical zero-knowledge circuit that enables private withdrawals from the Privacy Pool, ensuring:

- Proof of fund ownership
- Approval by Association Set Provider
- Spending of valid commitments
- Integrity of withdrawal transactions

## Circuit Design

### High-Level Architecture

The circuit verifies a withdrawal by:

1. Proving ownership of some commitment
2. Proving existance of the commitment in the state
3. Proving ASP approval of the label
4. Proving a valid value operation (withdrawn is less or equal than current value)

## Circuit Parameters

### Public Inputs

| Name             | Description                                         |
| ---------------- | --------------------------------------------------- |
| `withdrawnValue` | Amount being withdrawn from the existing commitment |
| `stateRoot`      | Current root of the state Merkle tree               |
| `stateTreeDepth` | Current depth of the state tree                     |
| `ASPRoot`        | Latest Association Set Provider root                |
| `ASPTreeDepth`   | Current depth of the ASP tree                       |
| `context`        | Cryptographic context for withdrawal integrity      |

### Private Inputs

| Name                | Description                                              |
| ------------------- | -------------------------------------------------------- |
| `label`             | Unique identifier for the commitment                     |
| `existingValue`     | Total value of the existing commitment                   |
| `existingNullifier` | Nullifier of the existing commitment                     |
| `existingSecret`    | Secret of the existing commitment                        |
| `newNullifier`      | Nullifier for the new commitment                         |
| `newSecret`         | Secret for the new commitment                            |
| `stateSiblings`     | Merkle tree sibling nodes for state tree inclusion proof |
| `stateIndex`        | Index of the commitment in the state tree                |
| `ASPSiblings`       | Merkle tree sibling nodes for ASP tree inclusion proof   |
| `ASPIndex`          | Index of the label in the ASP tree                       |

### Outputs

| Name                    | Description                                   |
| ----------------------- | --------------------------------------------- |
| `newCommitmentHash`     | Hash of the new commitment after withdrawal   |
| `existingNullifierHash` | Hash of the nullifier of the spent commitment |

## Circuit Logic

### Withdrawal Verification Steps

1. **Compute Existing Commitment**

   - Hash the existing commitment from the privately provided preimage

2. **State Tree Inclusion Proof**

   - Verify that the existing commitment is in the state tree
   - Uses LeanIMT inclusion proof verification

3. **ASP Label Verification**

   - Confirm the label is present in the Association Set Provider (ASP) tree
   - Ensures withdrawal is approved by the ASP

4. **Value Validation**

   - Check that withdrawn amount is valid
   - Compute remaining value after withdrawal
   - Verify both withdrawn and remaining values are within acceptable ranges

5. **New Commitment Generation**
   - Create a new commitment representing the remaining balance
   - Use the same label, new nullifier, and new secret

## Security Properties

- **Non-Malleability**: Impossible to modify withdrawal without knowing original secrets
- **Privacy**: No information about original commitment is revealed
- **Double-Spend Prevention**: Nullifier hash ensures each commitment can only be spent once
- **ASP Validation**: Ensures withdrawals are approved by the Association Set Provider

## Advanced Features

- Supports partial and full withdrawals
- Maintains commitment label across withdrawals
- Cryptographically secure commitment regeneration
- Flexible tree depth support

## Error Handling

Circuit will fail verification if:

- Commitment not found in state tree
- Label not found in ASP tree
- Withdrawal amount exceeds existing balance
