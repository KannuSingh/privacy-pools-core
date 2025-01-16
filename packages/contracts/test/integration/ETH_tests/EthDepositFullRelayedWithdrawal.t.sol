// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

contract IntegrationEthDepositFullRelayedWithdrawal is IntegrationBase {
  function test_EthDepositFullRelayedWithdrawal() public {
    /*///////////////////////////////////////////////////////////////
                                 DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // Generate deposit params
    DepositParams memory _params = _generateDepositParams(100 ether, _VETTING_FEE_BPS, _ethPool);

    // Deal ETH to Alice
    deal(_ALICE, _params.amount);

    // Expect deposit event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.Deposited(_ALICE, _params.commitment, _params.label, _params.amountAfterFee, _params.commitment);

    // Expect deposit event from entrypoint
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.Deposited(_ALICE, _ethPool, _params.commitment, _params.amountAfterFee);

    // Assert balances
    uint256 _aliceInitialBalance = _ALICE.balance;
    uint256 _entrypointInitialBalance = address(_entrypoint).balance;
    uint256 _ethPoolInitialBalance = address(_ethPool).balance;
    uint256 _relayerInitialBalance = _RELAYER.balance;

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

    // Generate withdrawal params
    (IPrivacyPool.Withdrawal memory _withdrawal, ProofLib.Proof memory _proof) = _generateWithdrawalParams(
      WithdrawalParams({
        processor: address(_entrypoint),
        recipient: _ALICE,
        feeRecipient: _RELAYER,
        feeBps: _RELAY_FEE_BPS,
        scope: _params.scope,
        withdrawnValue: _params.amountAfterFee,
        stateRoot: _params.commitment,
        nullifier: _params.nullifier
      })
    );

    // Calculate received amount
    uint256 _receivedAmount = _deductFee(_params.amountAfterFee, _RELAY_FEE_BPS);

    // Push ASP root
    vm.prank(_POSTMAN);
    _entrypoint.updateRoot(_proof.pubSignals[3], bytes32('IPFS_HASH'));

    // TODO: remove once we have a verifier
    vm.mockCall(address(_VERIFIER), abi.encodeWithSelector(IVerifier.verifyProof.selector, _proof), abi.encode(true));

    // Expect withdrawal event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.Withdrawn(
      address(_entrypoint), _params.amountAfterFee, _proof.pubSignals[6], _proof.pubSignals[7]
    );

    // Expect withdrawal event from entrypoint
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.WithdrawalRelayed(
      _RELAYER, _ALICE, _ETH, _params.amountAfterFee, _params.amountAfterFee - _receivedAmount
    );

    // Withdraw ETH
    vm.prank(_RELAYER);
    _entrypoint.relay(_withdrawal, _proof);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount + _receivedAmount, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance, 'EthPool balance mismatch');
    assertEq(
      _RELAYER.balance, _relayerInitialBalance + _params.amountAfterFee - _receivedAmount, 'Relayer balance mismatch'
    );
  }
}
