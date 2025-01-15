// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';
import {IVerifier} from 'interfaces/IVerifier.sol';

contract IntegrationEthDepositPartialDirectWithdrawal is IntegrationBase {
  function test_EthDepositPartialDirectWithdrawal() public {
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

    // Deposit ETH
    vm.prank(_ALICE);
    _entrypoint.deposit{value: _params.amount}(_params.precommitment);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance + _params.amountAfterFee, 'EthPool balance mismatch');

    // Assert deposit info
    (address _depositor, uint256 _value, uint256 _cooldownExpiry) = _ethPool.deposits(_params.label);
    assertEq(_depositor, _ALICE, 'Incorrect depositor');
    assertEq(_value, _params.amountAfterFee, 'Incorrect deposit value');
    assertEq(_cooldownExpiry, block.timestamp + 1 weeks, 'Incorrect deposit cooldown expiry');

    /*///////////////////////////////////////////////////////////////
                                 WITHDRAW
    //////////////////////////////////////////////////////////////*/

    // Withdraw half of the deposit
    uint256 _withdrawnValue = _params.amountAfterFee / 2;

    // Data is left empty given that the withdrawal is direct
    (IPrivacyPool.Withdrawal memory _withdrawal, ProofLib.Proof memory _proof) = _generateWithdrawalParams(
      WithdrawalParams({
        processor: _ALICE,
        recipient: address(0),
        feeRecipient: address(0),
        feeBps: 0,
        scope: _params.scope,
        withdrawnValue: _withdrawnValue,
        stateRoot: _params.commitment,
        nullifier: _params.nullifier
      })
    );

    // Push ASP root
    vm.prank(_POSTMAN);
    _entrypoint.updateRoot(_proof.pubSignals[3], bytes32('IPFS_HASH'));

    // TODO: remove once we have a verifier
    vm.mockCall(address(_VERIFIER), abi.encodeWithSelector(IVerifier.verifyProof.selector, _proof), abi.encode(true));

    // Expect withdrawal event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.Withdrawn(_ALICE, _withdrawnValue, _proof.pubSignals[6]);

    // Withdraw ETH
    vm.prank(_ALICE);
    _ethPool.withdraw(_withdrawal, _proof);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount + _withdrawnValue, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(
      address(_ethPool).balance,
      _ethPoolInitialBalance + _params.amountAfterFee - _withdrawnValue,
      'EthPool balance mismatch'
    );
  }
}
