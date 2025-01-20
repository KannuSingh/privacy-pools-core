// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

contract IntegrationEthDepositPartialRelayedWithdrawal is IntegrationBase {
  function test_EthDepositPartialRelayedWithdrawal() public {
    /*///////////////////////////////////////////////////////////////
                                 DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // Generate deposit params
    DepositParams memory _params = _generateDefaultDepositParams(100 ether, _VETTING_FEE_BPS, _ethPool);

    // Deal ETH to Alice
    deal(_ALICE, _params.amount);

    // Expect deposit event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.Deposited(_ALICE, _params.commitment, _params.label, _params.amountAfterFee, _params.commitment);

    // Expect deposit event from entrypoint
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.Deposited(_ALICE, _ethPool, _params.commitment, _params.amountAfterFee);

    uint256 _aliceInitialBalance = _ALICE.balance;
    uint256 _entrypointInitialBalance = address(_entrypoint).balance;
    uint256 _ethPoolInitialBalance = address(_ethPool).balance;
    uint256 _relayerInitialBalance = _RELAYER.balance;

    // Add the commitment to the shadow merkle tree
    _insertIntoShadowMerkleTree(_params.commitment);

    // Deposit ETH
    vm.prank(_ALICE);
    _entrypoint.deposit{value: _params.amount}(_params.precommitment);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance + _params.amountAfterFee, 'EthPool balance mismatch');

    /*///////////////////////////////////////////////////////////////
                                 WITHDRAW
    //////////////////////////////////////////////////////////////*/
    // Withdraw partial amount
    uint256 _withdrawnValue = _params.amountAfterFee / 2;

    // Insert leaf into shadow asp merkle tree
    _insertIntoShadowASPMerkleTree(_DEFAULT_ASP_ROOT);

    // Generate withdrawal params
    (IPrivacyPool.Withdrawal memory _withdrawal, ProofLib.WithdrawProof memory _proof) = _generateWithdrawalParams(
      WithdrawalParams({
        processor: address(_entrypoint),
        recipient: _ALICE,
        feeRecipient: _RELAYER,
        feeBps: _RELAY_FEE_BPS,
        scope: _params.scope,
        // Notice we withdraw half of the deposit
        withdrawnValue: _withdrawnValue,
        nullifier: _params.nullifier
      })
    );

    // Push ASP root
    vm.prank(_POSTMAN);
    // pubSignals[3] is the ASPRoot
    _entrypoint.updateRoot(_proof.pubSignals[3], bytes32('IPFS_HASH'));

    // Calculate received amount
    uint256 _receivedAmount = _deductFee(_withdrawnValue, _RELAY_FEE_BPS);

    // TODO: remove once we have a verifier
    vm.mockCall(
      address(_WITHDRAWAL_VERIFIER),
      abi.encodeWithSignature('verifyProof((uint256[2],uint256[2][2],uint256[2],uint256[8]))', _proof),
      abi.encode(true)
    );

    // Expect withdrawal event from privacy pool
    vm.expectEmit(address(_ethPool));
    // pubSignals[6] is the existingNullifierHash
    // pubSignals[7] is the newCommitmentHash
    emit IPrivacyPool.Withdrawn(address(_entrypoint), _withdrawnValue, _proof.pubSignals[6], _proof.pubSignals[7]);

    // Expect withdrawal event from entrypoint
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(_RELAYER, _ALICE, _ETH, _withdrawnValue, _withdrawnValue - _receivedAmount);

    // Withdraw ETH
    vm.prank(_RELAYER);
    _entrypoint.relay(_withdrawal, _proof);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount + _receivedAmount, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance + _withdrawnValue, 'EthPool balance mismatch');
    assertEq(_RELAYER.balance, _relayerInitialBalance + _withdrawnValue - _receivedAmount, 'Relayer balance mismatch');
  }
}
