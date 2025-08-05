# PrivacyPoolPaymaster Documentation

## Overview

The `PrivacyPoolPaymaster` is an ERC-4337 paymaster contract designed to sponsor Privacy Pool withdrawal operations. It performs comprehensive validation to ensure it only sponsors UserOperations that will succeed in actual execution, preventing gas waste and potential exploits.

## Architecture

The paymaster integrates with three core contracts:
- **Privacy Pool Entrypoint**: The main relay contract that processes withdrawals
- **ETH Privacy Pool**: The actual privacy pool where funds are stored
- **Withdrawal Verifier**: Groth16 verifier for zero-knowledge proofs

## Validation Flow

The paymaster performs a complete validation chain that mirrors both `Entrypoint.relay()` and `PrivacyPool.withdraw()` methods to guarantee successful execution.

### 1. UserOperation Structure Validation

#### CallData Decoding
```solidity
function _decodeExecuteCallData(bytes calldata callData) 
    returns (address target, uint256 value, bytes memory data)
```

**Validates:**
- ✅ CallData has proper SimpleAccount.execute() selector (`0xb61d27f6`)
- ✅ CallData length is sufficient (≥4 bytes)
- ✅ Properly decodes target address, value, and data

#### Target Contract Validation
```solidity
if (target != address(PRIVACY_POOL_ENTRYPOINT)) {
    return ("", _packValidationData(true, 0, 0));
}
```

**Ensures:**
- ✅ Target must be the Privacy Pool Entrypoint contract
- ✅ Prevents calls to arbitrary contracts

#### ETH Value Validation
```solidity
if (value != 0) {
    return ("", _packValidationData(true, 0, 0));
}
```

**Ensures:**
- ✅ No direct ETH transfers in the UserOperation
- ✅ All value transfers happen through Privacy Pool mechanisms

### 2. Entrypoint.relay() Validation

The paymaster replicates all checks from `Entrypoint.relay()`:

#### Withdrawn Amount Check
```solidity
if (proof.withdrawnValue() == 0) return false;
```

**Validates:**
- ✅ Withdrawal amount is non-zero
- ✅ Matches `Entrypoint.relay()` first check

#### Processooor Validation
```solidity
if (withdrawal.processooor != address(PRIVACY_POOL_ENTRYPOINT)) return false;
```

**Validates:**
- ✅ Processooor is set to Privacy Entrypoint
- ✅ Matches `Entrypoint.relay()` processooor check

#### Pool Existence Check
```solidity
IPrivacyPool pool = PRIVACY_POOL_ENTRYPOINT.scopeToPool(scope);
if (address(pool) != address(ETH_PRIVACY_POOL)) return false;
```

**Validates:**
- ✅ Pool exists for the given scope
- ✅ Pool matches expected ETH Privacy Pool
- ✅ Matches `Entrypoint.relay()` pool lookup

#### Relay Fee Validation
```solidity
if (relayData.relayFeeBPS > _maxRelayFeeBPS) return false;
```

**Validates:**
- ✅ Relay fee doesn't exceed maximum allowed
- ✅ Uses asset configuration from Entrypoint
- ✅ Matches `Entrypoint.relay()` fee validation

### 3. PrivacyPool.withdraw() Validation

The paymaster replicates all checks from the `validWithdrawal` modifier and `withdraw()` function:

#### Context Integrity Check
```solidity
uint256 expectedContext = uint256(
    keccak256(abi.encode(withdrawal, ETH_PRIVACY_POOL.SCOPE()))
) % Constants.SNARK_SCALAR_FIELD;

if (proof.context() != expectedContext) return false;
```

**Validates:**
- ✅ Proof context matches withdrawal data and pool scope
- ✅ Prevents proof reuse across different withdrawals/pools
- ✅ Matches `validWithdrawal` modifier context check

#### Tree Depth Validation
```solidity
if (
    proof.stateTreeDepth() > ETH_PRIVACY_POOL.MAX_TREE_DEPTH() ||
    proof.ASPTreeDepth() > ETH_PRIVACY_POOL.MAX_TREE_DEPTH()
) {
    return false;
}
```

**Validates:**
- ✅ State tree depth within limits
- ✅ ASP tree depth within limits
- ✅ Matches `validWithdrawal` modifier tree depth check

#### State Root Validation
```solidity
function _isKnownRoot(uint256 _root) internal view returns (bool) {
    if (_root == 0) return false;
    
    uint32 _index = ETH_PRIVACY_POOL.currentRootIndex();
    uint32 ROOT_HISTORY_SIZE = ETH_PRIVACY_POOL.ROOT_HISTORY_SIZE();
    
    for (uint32 _i = 0; _i < ROOT_HISTORY_SIZE; _i++) {
        if (_root == ETH_PRIVACY_POOL.roots(_index)) return true;
        _index = (_index + ROOT_HISTORY_SIZE - 1) % ROOT_HISTORY_SIZE;
    }
    
    return false;
}
```

**Validates:**
- ✅ State root exists in recent history (64 roots)
- ✅ Implements exact same logic as `State._isKnownRoot()`
- ✅ Matches `validWithdrawal` modifier state root check

#### ASP Root Validation
```solidity
if (aspRoot != PRIVACY_POOL_ENTRYPOINT.latestRoot()) return false;
```

**Validates:**
- ✅ ASP root matches latest published root
- ✅ Ensures proof uses current association set
- ✅ Matches `validWithdrawal` modifier ASP root check

#### Nullifier Validation
```solidity
uint256 nullifierHash = proof.existingNullifierHash();
if (ETH_PRIVACY_POOL.nullifierHashes(nullifierHash)) return false;
```

**Validates:**
- ✅ Nullifier hasn't been spent previously
- ✅ Prevents double-spending attacks
- ✅ Matches `PrivacyPool.withdraw()` nullifier check

#### Zero-Knowledge Proof Verification
```solidity
if (
    !WITHDRAWAL_VERIFIER.verifyProof(
        proof.pA,
        proof.pB,
        proof.pC,
        proof.pubSignals
    )
) {
    return false;
}
```

**Validates:**
- ✅ Groth16 proof is mathematically valid
- ✅ Uses same verifier as Privacy Pool
- ✅ Matches `PrivacyPool.withdraw()` proof verification

### 4. Paymaster Economics Validation

#### Fee Coverage Check
```solidity
uint256 feeAmount = (withdrawnAmount * relayData.relayFeeBPS) / 10_000;
if (feeAmount < maxCost) {
    return ("", _packValidationData(true, 0, 0));
}
```

**Validates:**
- ✅ Relay fee covers maximum gas cost
- ✅ Uses same fee calculation as Entrypoint
- ✅ Prevents under-compensation

#### Fee Recipient Validation
```solidity
if (relayData.feeRecipient != address(this)) {
    return ("", _packValidationData(true, 0, 0));
}
```

**Validates:**
- ✅ Paymaster will receive the relay fees
- ✅ Ensures economic sustainability

## Security Guarantees

### 1. No False Positives
The paymaster will **never** approve a UserOperation that would fail in execution because it performs identical validation to the actual Privacy Pool contracts.

### 2. Complete Validation Coverage
Every check performed by both `Entrypoint.relay()` and `PrivacyPool.withdraw()` is replicated in the paymaster:

| Validation | Entrypoint.relay() | PrivacyPool.withdraw() | Paymaster |
|------------|-------------------|----------------------|-----------|
| Withdrawn amount > 0 | ✅ | ✅ | ✅ |
| Correct processooor | ✅ | ✅ | ✅ |
| Pool exists | ✅ | - | ✅ |
| Context integrity | - | ✅ | ✅ |
| Tree depths | - | ✅ | ✅ |
| State root validity | - | ✅ | ✅ |
| ASP root validity | - | ✅ | ✅ |
| Nullifier not spent | - | ✅ | ✅ |
| ZK proof valid | - | ✅ | ✅ |
| Fee validation | ✅ | - | ✅ |

### 3. Economic Protection
- ✅ Only sponsors operations where relay fees exceed gas costs
- ✅ Ensures paymaster receives appropriate compensation
- ✅ Validates fee calculations match Entrypoint logic

### 4. Attack Prevention
- ✅ **Replay Attack**: Context validation prevents proof reuse
- ✅ **Double Spend**: Nullifier validation prevents multiple spends
- ✅ **Cross-Pool Attack**: Scope validation ensures pool-specific proofs
- ✅ **Fee Manipulation**: Direct fee validation against Entrypoint configuration
- ✅ **Proof Forgery**: Full Groth16 verification using same verifier
- ✅ **State Manipulation**: Root validation ensures current pool state

## Error Conditions

The paymaster returns validation failure (`_packValidationData(true, 0, 0)`) for:

1. **Invalid CallData Structure**
   - Wrong function selector
   - Insufficient data length
   - Malformed parameters

2. **Incorrect Target Contract**
   - Target is not Privacy Entrypoint
   - Direct ETH transfers attempted

3. **Failed Entrypoint Validation**
   - Zero withdrawal amount
   - Wrong processooor address
   - Pool doesn't exist
   - Excessive relay fees

4. **Failed Privacy Pool Validation**
   - Context mismatch
   - Tree depth exceeded
   - Unknown state root
   - Incorrect ASP root
   - Nullifier already spent
   - Invalid ZK proof

5. **Economic Validation Failure**
   - Insufficient fee coverage
   - Wrong fee recipient

## Integration Notes

### Gas Estimation
The paymaster is compatible with ERC-4337 gas estimation flows, allowing accurate gas cost predictions for sponsored operations.

### Fee Structure
- Relay fees are calculated as: `(withdrawnAmount * relayFeeBPS) / 10_000`
- Must equal or exceed `maxCost` parameter from ERC-4337 validation
- Fee recipient must be the paymaster contract address

### State Dependencies
The paymaster relies on current Privacy Pool state:
- Pool contract addresses and configuration
- Merkle tree root history
- Nullifier spent status
- ASP root updates

### Upgradeability
The paymaster is designed for specific Privacy Pool deployments and should be updated if the underlying Privacy Pool contracts change.

## Conclusion

The `PrivacyPoolPaymaster` provides a secure, comprehensive validation layer that guarantees successful Privacy Pool withdrawals while protecting against various attack vectors. By replicating the exact validation logic of both Entrypoint and Privacy Pool contracts, it ensures reliable transaction sponsorship without risk of gas waste or economic exploitation.