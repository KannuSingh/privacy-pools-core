// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {ERC1967Proxy} from '@oz/proxy/ERC1967/ERC1967Proxy.sol';
import {IERC20} from '@oz/token/ERC20/ERC20.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {Constants} from 'contracts/lib/Constants.sol';
import {DeployLib} from 'contracts/lib/DeployLib.sol';

import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';

import {Entrypoint} from 'contracts/Entrypoint.sol';
import {PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';
import {CommitmentVerifier} from 'contracts/verifiers/CommitmentVerifier.sol';
import {WithdrawalVerifier} from 'contracts/verifiers/WithdrawalVerifier.sol';

/*///////////////////////////////////////////////////////////////
                    BASE DEPLOY SCRIPT
//////////////////////////////////////////////////////////////*/

/**
 * @notice Abstract script to deploy the PrivacyPool protocol.
 * @dev Assets and chain specific configurations must be defined in a parent contract.
 */
abstract contract DeployProtocol is Script {
  // @notice Struct for Pool deployment and configuration
  struct PoolConfig {
    string symbol;
    IERC20 asset;
    uint256 minimumDepositAmount;
    uint256 vettingFeeBPS;
    uint256 maxRelayFeeBPS;
  }

  error ChainIdAndRPCMismatch();

  // @notice Deployed Entrypoint
  Entrypoint public entrypoint;
  // @notice Deployed Groth16 Withdrawal Verifier
  address public withdrawalVerifier;
  // @notice Deployed Groth16 Ragequit Verifier
  address public ragequitVerifier;

  // @notice Initial Entrypoint `ONWER_ROLE`
  address public owner;
  // @notice Initial Entrypoint `POSTMAN_ROLE`
  address public postman;

  address public deployer;

  // @notice CreateX Singleton
  ICreateX public constant CreateX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

  // @notice Native asset pool configuration
  PoolConfig internal _nativePoolConfig;
  // @notice ERC20 pools configurations
  PoolConfig[] internal _tokenPoolConfigs;

  function setUp() public virtual {
    owner = vm.envAddress('OWNER_ADDRESS');
    postman = vm.envAddress('POSTMAN_ADDRESS');

    deployer = vm.envAddress('DEPLOYER_ADDRESS');
  }

  // @dev Must be called with the `--account` flag which acts as the caller
  function run() public virtual {
    vm.startBroadcast(deployer);

    // Deploy verifiers
    _deployGroth16Verifiers();
    // Deploy Entrypoint
    _deployEntrypoint();

    // Deploy the native asset pool
    _deploySimplePool(_nativePoolConfig);

    // Deploy the ERC20 pools
    for (uint256 _i; _i < _tokenPoolConfigs.length; ++_i) {
      _deployComplexPool(_tokenPoolConfigs[_i]);
    }

    vm.stopBroadcast();
  }

  function _deployGroth16Verifiers() private {
    // Deploy WithdrawalVerifier using Create2
    withdrawalVerifier = CreateX.deployCreate2(
      DeployLib.salt(deployer, DeployLib.WITHDRAWAL_VERIFIER_SALT),
      abi.encodePacked(type(WithdrawalVerifier).creationCode)
    );

    console.log('Withdrawal Verifier deployed at: %s', withdrawalVerifier);

    // Deploy CommitmentVerifier using Create2
    ragequitVerifier = CreateX.deployCreate2(
      DeployLib.salt(deployer, DeployLib.RAGEQUIT_VERIFIER_SALT),
      abi.encodePacked(type(CommitmentVerifier).creationCode)
    );

    console.log('Ragequit Verifier deployed at: %s', ragequitVerifier);
  }

  function _deployEntrypoint() private {
    // Deploy Entrypoint implementation
    address _impl =
      CreateX.deployCreate2(DeployLib.salt(deployer, DeployLib.ENTRYPOINT_IMPL_SALT), type(Entrypoint).creationCode);

    // Encode `initialize` call data
    bytes memory _intializationData = abi.encodeCall(Entrypoint.initialize, (owner, postman));

    // Deploy proxy and initialize
    address _entrypoint = CreateX.deployCreate2(
      DeployLib.salt(deployer, DeployLib.ENTRYPOINT_PROXY_SALT),
      abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_impl, _intializationData))
    );

    entrypoint = Entrypoint(payable(_entrypoint));

    console.log('Entrypoint deployed at: %s', address(entrypoint));
  }

  function _deploySimplePool(PoolConfig memory _config) private {
    // Deploy pool with Create2
    address _pool = CreateX.deployCreate2(
      DeployLib.salt(deployer, DeployLib.SIMPLE_POOL_SALT),
      abi.encodePacked(
        type(PrivacyPoolSimple).creationCode, abi.encode(address(entrypoint), withdrawalVerifier, ragequitVerifier)
      )
    );

    // Register pool at entrypoint with defined configuration
    entrypoint.registerPool(
      IERC20(Constants.NATIVE_ASSET),
      IPrivacyPool(_pool),
      _config.minimumDepositAmount,
      _config.vettingFeeBPS,
      _config.maxRelayFeeBPS
    );

    console.log('%s Pool deployed at: %s', _config.symbol, _pool);
  }

  function _deployComplexPool(PoolConfig memory _config) private {
    // Deploy pool with Create2
    address _pool = CreateX.deployCreate2(
      DeployLib.salt(deployer, DeployLib.COMPLEX_POOL_SALT),
      abi.encodePacked(
        type(PrivacyPoolComplex).creationCode,
        abi.encode(address(entrypoint), withdrawalVerifier, ragequitVerifier, address(_config.asset))
      )
    );

    // Register pool at entrypoint with defined configuration
    entrypoint.registerPool(
      _config.asset, IPrivacyPool(_pool), _config.minimumDepositAmount, _config.vettingFeeBPS, _config.maxRelayFeeBPS
    );

    console.log('%s Pool deployed at: %s', _config.symbol, _pool);
  }

  modifier chainId(uint256 _chainId) {
    if (block.chainid != _chainId) revert ChainIdAndRPCMismatch();
    _;
  }
}
