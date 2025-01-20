// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IntegrationBase} from '../IntegrationBase.sol';
import {IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';
import {IState} from 'interfaces/IState.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';

contract IntegrationERC20DepositRagequit is IntegrationBase {
  function test_ERC20DepositRagequit() public {
    /*///////////////////////////////////////////////////////////////
                                 DEPOSIT
    //////////////////////////////////////////////////////////////*/
    // Generate deposit params
    DepositParams memory _params = _generateDefaultDepositParams(100 ether, _VETTING_FEE_BPS, _daiPool);

    // Deal DAI to Alice
    deal(address(_DAI), _ALICE, _params.amount);

    // Approve entrypoint
    vm.startPrank(_ALICE);
    _DAI.approve(address(_entrypoint), _params.amount);

    // Expect deposit event from privacy pool
    vm.expectEmit(address(_daiPool));
    emit IPrivacyPool.Deposited(_ALICE, _params.commitment, _params.label, _params.amountAfterFee, _params.commitment);

    // Expect deposit event from entrypoint
    vm.expectEmit(address(_entrypoint));
    emit IEntrypoint.Deposited(_ALICE, _daiPool, _params.commitment, _params.amountAfterFee);

    // Assert balances
    uint256 _aliceInitialBalance = _DAI.balanceOf(_ALICE);
    uint256 _entrypointInitialBalance = _DAI.balanceOf(address(_entrypoint));
    uint256 _daiPoolInitialBalance = _DAI.balanceOf(address(_daiPool));

    // Add the commitment to the shadow merkle tree
    _insertIntoShadowMerkleTree(_params.commitment);

    // Deposit DAI
    _entrypoint.deposit(IERC20(_DAI), _params.amount, _params.precommitment);
    vm.stopPrank();

    // Assert balances
    assertEq(_DAI.balanceOf(_ALICE), _aliceInitialBalance - _params.amount, 'Alice balance mismatch');
    assertEq(
      _DAI.balanceOf(address(_entrypoint)), _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch'
    );
    assertEq(
      _DAI.balanceOf(address(_daiPool)), _daiPoolInitialBalance + _params.amountAfterFee, 'EthPool balance mismatch'
    );

    // Assert deposit info
    (address _depositor, uint256 _value, uint256 _cooldownExpiry) = _daiPool.deposits(_params.label);
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
    vm.expectEmit(address(_daiPool));
    emit IPrivacyPool.Ragequit(_ALICE, _params.commitment, _params.label, _params.amountAfterFee);

    // Initiate Ragequit
    vm.prank(_ALICE);
    _daiPool.ragequit(_ragequitProof);

    assertTrue(_daiPool.nullifierHashes(_hash(_params.nullifier)), 'Nullifier not spent');

    // Assert balances
    assertEq(_DAI.balanceOf(_ALICE), _aliceInitialBalance - _params.fee, 'Alice balance mismatch');
    assertEq(
      _DAI.balanceOf(address(_entrypoint)), _entrypointInitialBalance + _params.fee, 'Entrypoint balance mismatch'
    );
    assertEq(_DAI.balanceOf(address(_daiPool)), _daiPoolInitialBalance, 'EthPool balance mismatch');
  }
}
