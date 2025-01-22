// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';
import {IState} from 'interfaces/IState.sol';

contract IntegrationEthDepositRagequit is IntegrationBase {
  function test_EthDepositRagequit() public {
    /*///////////////////////////////////////////////////////////////
                                 DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // Generate deposit params
    DepositParams memory _params = _generateDefaultDepositParams(100 ether, _VETTING_FEE_BPS, _ethPool);
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

    // Add the commitment to the shadow merkle tree
    _insertIntoShadowMerkleTree(_params.commitment);

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

    // Generate ragequit proof
    ProofLib.RagequitProof memory _ragequitProof = _generateRagequitProof(
      _params.commitment, _params.precommitment, _params.nullifier, _params.amountAfterFee, _params.label
    );

    // TODO: remove when we have a verifier
    vm.mockCall(
      address(_RAGEQUIT_VERIFIER),
      abi.encodeWithSignature('verifyProof((uint256[2],uint256[2][2],uint256[2],uint256[5]))', _ragequitProof),
      abi.encode(true)
    );

    // Expect Ragequit initiated event from privacy pool
    vm.expectEmit(address(_ethPool));
    emit IPrivacyPool.Ragequit(_ALICE, _params.commitment, _params.label, _params.amountAfterFee);

    // Initiate Ragequit
    vm.prank(_ALICE);
    _ethPool.ragequit(_ragequitProof);

    assertTrue(_ethPool.nullifierHashes(_hashNullifier(_params.nullifier)), 'Nullifier not spent');

    // Assert balances
    assertEq(_ALICE.balance, _aliceInitialBalance - _params.fee, 'Alice balance mismatch');
    assertEq(address(_entrypoint).balance, _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch');
    assertEq(address(_ethPool).balance, _ethPoolInitialBalance, 'EthPool balance mismatch');
  }
}
