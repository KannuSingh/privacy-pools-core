# Protocol Components

## Commitments

A commitment is a cryptographic primitive that allows a user to prove ownership of value privately. In the Privacy Pool protocol, commitments are used to represent a user's ownership of value in a pool. The commitment is a hash of the owned amount, a unique label, and a secret value known only to the user.

## Association Sets

An association set is a merkle tree maintained by an off-chain service called the Association Set Provider (ASP). The ASP approves valid withdrawal labels by including them in the association set. The merkle root of the association set is periodically updated on the Entrypoint contract, allowing users to prove the validity of their withdrawal labels using merkle proofs.

## Zero-Knowledge Proofs

Zero-knowledge proofs (ZKPs) are cryptographic constructs that allow a prover to convince a verifier of the validity of a statement without revealing any additional information. In the Privacy Pool protocol, ZKPs are used to prove the validity of withdrawal and ragequit operations while preserving privacy of the users depending on the operation.
