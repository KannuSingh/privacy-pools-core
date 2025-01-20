// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';

import {PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';
import {CommitmentVerifier} from 'contracts/verifiers/CommitmentVerifier.sol';
import {WithdrawalVerifier} from 'contracts/verifiers/WithdrawalVerifier.sol';

import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

import {ERC20, IERC20} from '@oz/token/ERC20/ERC20.sol';

import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract TestToken is ERC20 {
  constructor() ERC20('Test Token', 'TST') {
    _mint(msg.sender, 1_000_000 * 10 ** decimals());
  }
}

contract DeployVerifier is Script {
  function run() public {
    vm.startBroadcast();

    CommitmentVerifier commitmentVerifier = new CommitmentVerifier();
    WithdrawalVerifier withdrawalVerifier = new WithdrawalVerifier();
    console.log('Commitment Verifier deployed at: %s', address(commitmentVerifier));
    console.log('Withdrawal Verifier deployed at: %s', address(withdrawalVerifier));

    vm.stopBroadcast();
  }
}

contract DeployEntrypoint is Script {
  Entrypoint public entrypoint;
  address public owner;
  address public postman;

  function setUp() public {
    owner = vm.envAddress('OWNER_ADDRESS');
    postman = vm.envAddress('POSTMAN_ADDRESS');
  }

  function run() public {
    vm.startBroadcast();

    address _impl = address(new Entrypoint());
    entrypoint = Entrypoint(
      payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(Entrypoint.initialize, (owner, postman))))
    );

    console.log('Entrypoint proxy deployed at: %s', address(entrypoint));
    console.log('Entrypoint implementation deployed at: %s', _impl);

    vm.stopBroadcast();
  }
}

contract DeployPoolSimple is Script {
  PrivacyPoolSimple public pool;

  address public entrypoint;
  address public withdrawalVerifier;
  address public ragequitVerifier;

  function setUp() public {
    entrypoint = vm.envAddress('ENTRYPOINT_ADDRESS');
    withdrawalVerifier = vm.envAddress('WITHDRAWAL_VERIFIER_ADDRESS');
    ragequitVerifier = vm.envAddress('RAGEQUIT_VERIFIER_ADDRESS');
  }

  function run() public {
    vm.startBroadcast();

    pool = new PrivacyPoolSimple(entrypoint, withdrawalVerifier, ragequitVerifier);
    console.log('Pool deployed at: %s', address(pool));

    vm.stopBroadcast();
  }
}

contract DeployPoolComplex is Script {
  PrivacyPoolComplex public pool;

  address public entrypoint;
  address public withdrawalVerifier;
  address public ragequitVerifier;
  address public asset;

  function setUp() public {
    entrypoint = vm.envAddress('ENTRYPOINT_ADDRESS');
    withdrawalVerifier = vm.envAddress('WITHDRAWAL_VERIFIER_ADDRESS');
    ragequitVerifier = vm.envAddress('RAGEQUIT_VERIFIER_ADDRESS');

    asset = vm.parseAddress(vm.prompt('Enter asset address'));
  }

  function run() public {
    vm.startBroadcast();

    pool = new PrivacyPoolComplex(entrypoint, withdrawalVerifier, ragequitVerifier, asset);
    console.log('Pool deployed at: %s', address(pool));

    vm.stopBroadcast();
  }
}

contract DeployProtocol is Script {
  IPrivacyPool public poolSimple;
  IPrivacyPool public poolComplex;

  Entrypoint public entrypoint;
  WithdrawalVerifier public withdrawalVerifier;
  CommitmentVerifier public ragequitVerifier;
  IERC20 public asset;

  address public owner;
  address public postman;

  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function setUp() public {
    owner = vm.envAddress('OWNER_ADDRESS');
    postman = vm.envAddress('POSTMAN_ADDRESS');
  }

  function run() public {
    vm.startBroadcast();

    // Deploy Verifier
    withdrawalVerifier = new WithdrawalVerifier();
    ragequitVerifier = new CommitmentVerifier();

    // Deploy Entrypoint (proxy + implementation)
    address _impl = address(new Entrypoint());
    entrypoint = Entrypoint(
      payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(Entrypoint.initialize, (owner, postman))))
    );

    // Deploy native asset Pool
    poolSimple = IPrivacyPool(
      address(new PrivacyPoolSimple(address(entrypoint), address(withdrawalVerifier), address(ragequitVerifier)))
    );

    // Deploy test token
    asset = IERC20(address(new TestToken()));

    // Deploy TestToken Pool
    poolComplex = IPrivacyPool(
      address(
        new PrivacyPoolComplex(
          address(entrypoint), address(withdrawalVerifier), address(ragequitVerifier), address(asset)
        )
      )
    );

    entrypoint.registerPool(IERC20(ETH), poolSimple, 0, 100);

    entrypoint.registerPool(asset, poolComplex, 0, 100);

    console.log('Withdrawal Verifier deployed at: %s', address(withdrawalVerifier));
    console.log('Ragequit Verifier deployed at: %s', address(ragequitVerifier));
    console.log('Entrypoint deployed at: %s', address(entrypoint));
    console.log('Pool Simple deployed at: %s', address(poolSimple));
    console.log('Pool Complex deployed at: %s', address(poolComplex));
    console.log('Test asset deployed at: %s', address(asset));

    console.log('Registered Simple Pool');
    console.log('Registered Complex Pool');

    vm.stopBroadcast();
  }
}
