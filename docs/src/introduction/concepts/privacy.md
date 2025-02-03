# Privacy

## Privacy Sets

In the Privacy Pool protocol, a privacy set refers to a group of users who have deposited assets into a pool. The privacy set provides anonymity for individual users, as their specific actions (deposits, withdrawals) are not directly linked to their identities.

## Anonymity

Anonymity in the Privacy Pool protocol is achieved through the use of zero-knowledge proofs. When a user withdraws from the protocol, they generate a proof that verifies the validity of their action without revealing their identity or some specific details of the transaction.

## Unlinkability

Unlinkability refers to the property that multiple transactions by the same user cannot be linked together. In the Privacy Pool protocol, this is achieved through the use of unique nullifiers for each transaction. Nullifiers are random values that are included in the zero-knowledge proofs and prevent double-spending of commitments.

## Privacy Limitations

The Privacy Pool protocol has some limitations:

- The ASP service is trusted.
- The anonymity set size is limited by the number of users in a specific pool. Smaller anonymity sets may be more susceptible to de-anonymization attacks.
- The protocol does not provide protection against network-level attacks, such as timing analysis or traffic correlation.

Users should be aware of these limitations when deciding to use the Privacy Pool protocol.
