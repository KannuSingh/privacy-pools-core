# Protocol Mechanisms

## Deposit Process

To deposit assets into a Privacy Pool, a user generates a commitment by depositing some amount along with a secret value to the Entrypoint. A commitment is generated on-chain which is added to appropriate pool's state merkle tree. The depositor's address and the specific deposit amount is revealed on-chain.

## Withdrawal Process

To withdraw assets from a Privacy Pool, a user generates a zero-knowledge proof that demonstrates the the ownership of some value in the pool and that the original deposit was approved by an ASP. The proof includes a merkle proof of the commitment's inclusion in the pool's state tree and a merkle proof of the label's inclusion in the ASP's association set. The recipient's address and the withdrawn amount are revealed on-chain.

## Ragequit Process

Ragequit is a withdrawal mechanism that allows users to withdraw their funds from a pool **while revealing their identity**. This allows users who have not been approved by an ASP to retrieve their funds without providing privacy. To ragequit, a user generates a zero-knowledge proof that proves the ownership a commitment and submits it to the PrivacyPool contract. The contract verifies the proof and transfers the funds to the user.
