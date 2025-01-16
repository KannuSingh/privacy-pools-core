// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Entrypoint, IEntrypoint} from 'contracts/Entrypoint.sol';
import {IPrivacyPool} from 'contracts/PrivacyPool.sol';

import {IPrivacyPoolComplex, PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {IPrivacyPoolSimple, PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';

import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {IERC20} from '@oz/interfaces/IERC20.sol';
import {Test} from 'forge-std/Test.sol';

import {ProofLib} from 'contracts/lib/ProofLib.sol';

import {PoseidonT2} from 'poseidon/PoseidonT2.sol';
import {PoseidonT3} from 'poseidon/PoseidonT3.sol';
import {PoseidonT4} from 'poseidon/PoseidonT4.sol';

import {Constants} from 'test/helper/Constants.sol';

contract IntegrationBase is Test {
  struct DepositParams {
    uint256 amount;
    uint256 amountAfterFee;
    uint256 fee;
    uint256 secret;
    uint256 nullifier;
    uint256 precommitment;
    uint256 nonce;
    uint256 scope;
    uint256 label;
    uint256 commitment;
  }

  struct WithdrawalParams {
    address processor;
    address recipient;
    address feeRecipient;
    uint256 feeBps;
    uint256 scope;
    uint256 withdrawnValue;
    uint256 stateRoot;
    uint256 nullifier;
  }

  uint256 internal constant _FORK_BLOCK = 18_920_905;

  IEntrypoint internal _entrypoint;
  IPrivacyPoolSimple internal _ethPool;
  IPrivacyPoolComplex internal _daiPool;

  IERC20 internal constant _ETH = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  IERC20 internal constant _DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  address internal immutable _OWNER = makeAddr('OWNER');
  address internal immutable _POSTMAN = makeAddr('POSTMAN');
  address internal immutable _VERIFIER = makeAddr('VERIFIER');
  address internal immutable _RELAYER = makeAddr('RELAYER');
  address internal immutable _ALICE = makeAddr('ALICE');
  address internal immutable _BOB = makeAddr('BOB');

  uint256 internal constant _MIN_DEPOSIT = 1;
  uint256 internal constant _VETTING_FEE_BPS = 100; // 1%
  uint256 internal constant _RELAY_FEE_BPS = 100; // 1%

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    _deployContracts();
    _registerPools();
  }

  function _deployContracts() internal {
    // Deploy Entrypoint
    address _impl = address(new Entrypoint());

    _entrypoint = Entrypoint(
      payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(Entrypoint.initialize, (_OWNER, _POSTMAN))))
    );

    // Deploy ETH Pool
    _ethPool = new PrivacyPoolSimple(address(_entrypoint), address(_VERIFIER));

    // Deploy DAI Pool
    _daiPool = new PrivacyPoolComplex(address(_entrypoint), address(_VERIFIER), address(_DAI));
  }

  function _registerPools() internal {
    vm.startPrank(_OWNER);
    _entrypoint.registerPool(_ETH, IPrivacyPool(_ethPool), _MIN_DEPOSIT, _VETTING_FEE_BPS);
    _entrypoint.registerPool(_DAI, IPrivacyPool(_daiPool), _MIN_DEPOSIT, _VETTING_FEE_BPS);
    vm.stopPrank();
  }

  function _deductFee(uint256 _amount, uint256 _feeBps) internal pure returns (uint256 _amountAfterFee) {
    return _amount - (_amount * _feeBps) / 10_000;
  }

  function _hash(uint256 _nullifier) internal pure returns (uint256 _hash) {
    return PoseidonT2.hash([_nullifier]);
  }

  function _hash(uint256 _nullifier, uint256 _secret) internal pure returns (uint256 _hash) {
    return PoseidonT3.hash([_nullifier, _secret]);
  }

  function _hash(uint256 _amount, uint256 _label, uint256 _precommitment) internal pure returns (uint256 _hash) {
    return PoseidonT4.hash([_amount, _label, _precommitment]);
  }

  function _generateDepositParams(
    uint256 _amount,
    uint256 _feeBps,
    IPrivacyPool _pool
  ) internal view returns (DepositParams memory _params) {
    _params.amount = _amount;
    _params.amountAfterFee = _deductFee(_amount, _feeBps);
    _params.fee = _amount - _params.amountAfterFee;
    _params.secret = uint256(keccak256('SECRET'));
    _params.nullifier = uint256(keccak256('NULLIFIER'));
    _params.precommitment = _hash(_params.nullifier, _params.secret);
    _params.nonce = _pool.nonce();
    _params.scope = _pool.SCOPE();
    _params.label = uint256(keccak256(abi.encodePacked(_params.scope, ++_params.nonce)));
    _params.commitment = _hash(_params.amountAfterFee, _params.label, _params.precommitment);
  }

  function _generateWithdrawalParams(WithdrawalParams memory _params)
    internal
    pure
    returns (IPrivacyPool.Withdrawal memory _withdrawal, ProofLib.Proof memory _proof)
  {
    bytes memory _feeData = abi.encode(
      IEntrypoint.FeeData({
        recipient: _params.recipient,
        feeRecipient: _params.feeRecipient,
        relayFeeBPS: _params.feeBps
      })
    );
    _withdrawal = IPrivacyPool.Withdrawal(_params.processor, _params.scope, _feeData);
    uint256 _context = uint256(keccak256(abi.encode(_withdrawal, _params.scope)));
    uint256 _ASPRoot = uint256(keccak256('ASPRoot')) % Constants.SNARK_SCALAR_FIELD;
    uint256 _newCommitmentHash = uint256(keccak256('NEW_COMMITMENT_HASH')) % Constants.SNARK_SCALAR_FIELD;
    uint256 _nullifierHash = PoseidonT2.hash([_params.nullifier]);

    _proof = ProofLib.Proof({
      pA: [uint256(0), uint256(0)],
      pB: [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
      pC: [uint256(0), uint256(0)],
      pubSignals: [
        _params.withdrawnValue,
        _params.stateRoot,
        uint256(0), // pubSignals[2] is the stateTreeDepth
        _ASPRoot,
        uint256(0), // pubSignals[4] is the ASPTreeDepth
        _context, // calculation: uint256(keccak256(abi.encode(_withdrawal, _params.scope)));
        _nullifierHash,
        _newCommitmentHash
      ]
    });
  }
}
