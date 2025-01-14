// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';
import {Groth16Verifier} from 'contracts/Verifier.sol';
import {PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';

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
    uint256 _deployer = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_deployer);

    Groth16Verifier verifier = new Groth16Verifier();
    console.log('Groth16 Verifier deployed at: %s', address(verifier));

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
    uint256 _deployer = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_deployer);

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
  address public verifier;

  function setUp() public {
    entrypoint = vm.envAddress('ENTRYPOINT_ADDRESS');
    verifier = vm.envAddress('VERIFIER_ADDRESS');
  }

  function run() public {
    uint256 _deployer = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_deployer);

    pool = new PrivacyPoolSimple(entrypoint, verifier);
    console.log('Pool deployed at: %s', address(pool));

    vm.stopBroadcast();
  }
}

contract DeployPoolComplex is Script {
  PrivacyPoolComplex public pool;

  address public entrypoint;
  address public verifier;
  address public asset;

  function setUp() public {
    entrypoint = vm.envAddress('ENTRYPOINT_ADDRESS');
    verifier = vm.envAddress('VERIFIER_ADDRESS');

    asset = vm.parseAddress(vm.prompt('Enter asset address'));
  }

  function run() public {
    uint256 _deployer = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_deployer);

    pool = new PrivacyPoolComplex(entrypoint, verifier, asset);
    console.log('Pool deployed at: %s', address(pool));

    vm.stopBroadcast();
  }
}

contract DeployProtocol is Script {
  IPrivacyPool public poolSimple;
  IPrivacyPool public poolComplex;

  Entrypoint public entrypoint;
  Groth16Verifier public verifier;
  IERC20 public asset;

  address public owner;
  address public postman;

  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function setUp() public {
    owner = vm.envAddress('OWNER_ADDRESS');
    postman = vm.envAddress('POSTMAN_ADDRESS');
  }

  function run() public {
    uint256 _deployer = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_deployer);

    // Deploy Verifier
    verifier = new Groth16Verifier();

    // Deploy Entrypoint (proxy + implementation)
    address _impl = address(new Entrypoint());
    entrypoint = Entrypoint(
      payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(Entrypoint.initialize, (owner, postman))))
    );

    // Deploy native asset Pool
    poolSimple = IPrivacyPool(address(new PrivacyPoolSimple(address(entrypoint), address(verifier))));

    // Deploy test token
    asset = IERC20(address(new TestToken()));

    // Deploy TestToken Pool
    poolComplex = IPrivacyPool(address(new PrivacyPoolComplex(address(entrypoint), address(verifier), address(asset))));

    entrypoint.registerPool(IERC20(ETH), poolSimple, 0, 100);

    entrypoint.registerPool(asset, poolComplex, 0, 100);

    console.log('Verifier deployed at: %s', address(verifier));
    console.log('Entrypoint deployed at: %s', address(entrypoint));
    console.log('Pool Simple deployed at: %s', address(poolSimple));
    console.log('Pool Complex deployed at: %s', address(poolComplex));
    console.log('Test asset deployed at: %s', address(asset));

    console.log('Registered Simple Pool');
    console.log('Registered Complex Pool');

    vm.stopBroadcast();
  }
}
