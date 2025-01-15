// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {IState} from 'interfaces/IState.sol';

contract IntegrationEthDepositRagequit is IntegrationBase {
  function test_EthDepositRagequit() public {
    /*///////////////////////////////////////////////////////////////
                                 DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // Generate deposit params
    DepositParams memory _params = _generateDepositParams(100 ether, _VETTING_FEE_BPS, _ethPool);
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

    // Deposit ETH
    vm.prank(_ALICE);
    _entrypoint.deposit{value: _params.amount}(_params.precommitment);

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.amount, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance + _params.amountAfterFee, 'EthPool balance mismatch');

    // Assert deposit data
    (address _depositor, uint256 _value, uint256 _cooldownExpiry) = _ethPool.deposits(_params.label);
    assertEq(_depositor, _ALICE, 'Incorrect depositor');
    assertEq(_value, _params.amountAfterFee, 'Incorrect deposit value');
    assertEq(_cooldownExpiry, block.timestamp + 1 weeks, 'Incorrect deposit cooldown expiry');

    /*///////////////////////////////////////////////////////////////
                                 RAGEQUIT
    //////////////////////////////////////////////////////////////*/

    // Wait for cooldown to expire
    vm.warp(block.timestamp + 1 weeks);

    // Expect Ragequit initiated event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.RagequitInitiated(_ALICE, _params.commitment, _params.label, _params.amountAfterFee);

    // Initiate Ragequit
    vm.prank(_ALICE);
    _ethPool.initiateRagequit(_params.amountAfterFee, _params.label, _params.precommitment, _params.nullifier);

    assertEq(
      uint8(_ethPool.nullifierHashes(_hash(_params.nullifier))),
      uint8(IState.NullifierStatus.RAGEQUIT_PENDING),
      'Incorrect nullifier status'
    );

    // Expect Ragequit finalized event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.RagequitFinalized(_ALICE, _params.commitment, _params.label, _params.amountAfterFee);

    // Finalize Ragequit
    vm.prank(_ALICE);
    _ethPool.finalizeRagequit(_params.amountAfterFee, _params.label, _params.nullifier, _params.secret);

    // Assert nullifier status
    assertEq(
      uint8(_ethPool.nullifierHashes(_hash(_params.nullifier))),
      uint8(IState.NullifierStatus.RAGEQUIT_FINALIZED),
      'Incorrect nullifier status'
    );

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.fee, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance, 'EthPool balance mismatch');
  }
}
