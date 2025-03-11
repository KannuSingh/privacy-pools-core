// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {DeployLib} from 'contracts/lib/DeployLib.sol';
import {Test} from 'forge-std/Test.sol';

/**
 * @title IntegrationDeploy
 * @notice Integration test for verifying deterministic CREATE2 deployments across multiple chains
 * @dev This test ensures that Privacy Pool contracts are deployed to the same addresses
 * across different EVM-compatible chains (mainnet, sepolia, gnosis) using CREATE2
 */
contract IntegrationDeploy is Test {
  /**
   * @notice Structure to hold deployed contract addresses for a specific chain
   * @param commitmentVerifier Address of the CommitmentVerifier contract
   * @param withdrawalVerifier Address of the WithdrawalVerifier contract
   * @param entrypoint Address of the Entrypoint contract
   * @param nativePool Address of the PrivacyPoolSimple contract (for native assets)
   * @param tokenPool Address of the PrivacyPoolComplex contract (for ERC20 tokens)
   */
  struct Contracts {
    address commitmentVerifier;
    address withdrawalVerifier;
    address entrypoint;
    address nativePool;
    address tokenPool;
  }

  /**
   * @notice Structure to hold chain-specific configuration
   * @param id Chain ID
   * @param name Chain name (used for forking)
   * @param native Native token symbol
   * @param token Address of the ERC20 token to use for testing
   * @param tokenSymbol Symbol of the ERC20 token
   */
  struct ChainConfig {
    uint256 id;
    string name;
    string native;
    address token;
    string tokenSymbol;
  }

  /*///////////////////////////////////////////////////////////////
                      STATE VARIABLES 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Array of chain configurations to test
   */
  ChainConfig[] internal _chains;

  /**
   * @notice Mapping from chain ID to deployed contract addresses
   */
  mapping(uint256 _chainId => Contracts _contracts) internal _contracts;

  /**
   * @notice Address used for deployment operations
   */
  address internal immutable _DEPLOYER = makeAddr('DEPLOYER');

  /**
   * @notice Mock token address used for testing
   */
  address internal _TOKEN = makeAddr('singleton_token');

  /**
   * @notice Set up test environment with chain configurations
   * @dev Initializes configurations for mainnet, sepolia, and gnosis chains
   */
  function setUp() public {
    _chains.push(ChainConfig(1, 'mainnet', 'ETH', _TOKEN, 'SYMBOL'));

    _chains.push(ChainConfig(11_155_111, 'sepolia', 'ETH', _TOKEN, 'SYMBOL'));

    _chains.push(ChainConfig(100, 'gnosis', 'xDAI', _TOKEN, 'SYMBOL'));
  }

  /**
   * @notice Test deterministic CREATE2 deployments across multiple chains
   * @dev For each chain:
   *      1. Creates a fork of the chain
   *      2. Deploys all Privacy Pool contracts using DeployLib
   *      3. Stores the deployed addresses
   *      Then verifies that all contracts are deployed to the same addresses across chains
   */
  function test_create2() public virtual {
    for (uint256 _i; _i < _chains.length; ++_i) {
      ChainConfig memory _chain = _chains[_i];

      // Fork the chain
      vm.createSelectFork(vm.rpcUrl(_chain.name));
      vm.startPrank(_DEPLOYER);

      // Deploy contracts using DeployLib
      address _commitmentVerifier = address(DeployLib.deployCommitmentVerifier(_DEPLOYER));
      _contracts[_chain.id].commitmentVerifier = _commitmentVerifier;

      address _withdrawalVerifier = address(DeployLib.deployWithdrawalVerifier(_DEPLOYER));
      _contracts[_chain.id].withdrawalVerifier = _withdrawalVerifier;

      address _entrypoint = address(DeployLib.deployEntrypoint(_DEPLOYER, makeAddr('OWNER'), makeAddr('POSTMAN')));
      _contracts[_chain.id].entrypoint = _entrypoint;
      _contracts[_chain.id].nativePool =
        address(DeployLib.deploySimplePool(_DEPLOYER, _entrypoint, _withdrawalVerifier, _commitmentVerifier));
      _contracts[_chain.id].tokenPool = address(
        DeployLib.deployComplexPool(_DEPLOYER, _entrypoint, _withdrawalVerifier, _commitmentVerifier, _chain.token)
      );

      vm.stopPrank();
    }

    // Verify that contract addresses are the same across all chains
    assertTrue(
      _contracts[1].commitmentVerifier == _contracts[11_155_111].commitmentVerifier
        && _contracts[11_155_111].commitmentVerifier == _contracts[100].commitmentVerifier,
      "Commitment verifier addresses don't match"
    );

    assertTrue(
      _contracts[1].withdrawalVerifier == _contracts[11_155_111].withdrawalVerifier
        && _contracts[11_155_111].withdrawalVerifier == _contracts[100].withdrawalVerifier,
      "Withdrawal verifier addresses don't match"
    );

    assertTrue(
      _contracts[1].entrypoint == _contracts[11_155_111].entrypoint
        && _contracts[11_155_111].entrypoint == _contracts[100].entrypoint,
      "Entrypoint addresses don't match"
    );

    assertTrue(
      _contracts[1].nativePool == _contracts[11_155_111].nativePool
        && _contracts[11_155_111].nativePool == _contracts[100].nativePool,
      "Native pool addresses don't match"
    );

    assertTrue(
      _contracts[1].tokenPool == _contracts[11_155_111].tokenPool
        && _contracts[11_155_111].tokenPool == _contracts[100].tokenPool,
      "Complex pool addresses don't match"
    );
  }
}
