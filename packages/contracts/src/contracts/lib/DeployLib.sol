// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

import {Entrypoint} from 'contracts/Entrypoint.sol';
import {PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';
import {CommitmentVerifier} from 'contracts/verifiers/CommitmentVerifier.sol';
import {WithdrawalVerifier} from 'contracts/verifiers/WithdrawalVerifier.sol';

import {ERC1967Proxy} from '@oz/proxy/ERC1967/ERC1967Proxy.sol';
import {ICreateX} from 'interfaces/external/ICreateX.sol';

/**
 * @title DeployLib
 * @dev A library for deterministic deployment of Privacy Pool contracts and related components
 * using CREATE2 via the CreateX contract.
 *
 * This library provides functions to deploy:
 * - Entrypoint (as an UUPS proxy)
 * - Simple Privacy Pool (for native assets)
 * - Complex Privacy Pool (for ERC20 tokens)
 * - Commitment Verifier
 * - Withdrawal Verifier
 *
 * Each component is deployed with a deterministic address based on a predefined salt.
 */
library DeployLib {
  /**
   * @dev Reference to the CreateX contract for deterministic deployments
   * @notice The address is the same across all EVM-compatible chains
   */
  ICreateX public constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

  /**
   * @dev Predefined salt values for each contract type
   * @notice These values ensure deterministic addresses across deployments
   */
  bytes11 internal constant _ENTRYPOINT_SALT = bytes11(keccak256('Entrypoint'));
  bytes11 internal constant _SIMPLE_POOL_SALT = bytes11(keccak256(abi.encodePacked('PrivacyPoolSimple')));
  bytes11 internal constant _COMPLEX_POOL_SALT = bytes11(keccak256(abi.encodePacked('PrivacyPoolComplex')));
  bytes11 internal constant _WITHDRAWAL_VERIFIER_SALT = bytes11(keccak256(abi.encodePacked('WithdrawalVerifier')));
  bytes11 internal constant _RAGEQUIT_VERIFIER_SALT = bytes11(keccak256(abi.encodePacked('RagequitVerifier')));

  /**
   * @dev Deploys an Entrypoint contract as an upgradeable proxy
   * @param _deployer Address of the deployer used for salt generation
   * @param _initialOwner Address of the initial owner of the Entrypoint
   * @param _initialPostman Address of the initial postman for the Entrypoint
   * @return _entrypoint The deployed Entrypoint contract
   */
  function deployEntrypoint(
    address _deployer,
    address _initialOwner,
    address _initialPostman
  ) public returns (Entrypoint _entrypoint) {
    address _implementation = address(new Entrypoint());

    bytes memory _intializationData =
      abi.encodeWithSelector(Entrypoint.initialize.selector, _initialOwner, _initialPostman);

    address _deployedProxy = CREATEX.deployCreate2(
      _salt(_deployer, _ENTRYPOINT_SALT),
      abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_implementation, _intializationData))
    );

    _entrypoint = Entrypoint(payable(_deployedProxy));
  }

  /**
   * @dev Deploys a Simple Privacy Pool for native ETH
   * @param _deployer Address of the deployer used for salt generation
   * @param _entrypoint Address of the Entrypoint contract
   * @param _commitmentVerifier Address of the Commitment Verifier contract
   * @param _withdrawalVerifier Address of the Withdrawal Verifier contract
   * @return _pool The deployed Simple Privacy Pool contract
   */
  function deploySimplePool(
    address _deployer,
    address _entrypoint,
    address _commitmentVerifier,
    address _withdrawalVerifier
  ) public returns (PrivacyPoolSimple _pool) {
    bytes memory _constructorArgs = abi.encode(_entrypoint, _withdrawalVerifier, _commitmentVerifier);

    address _deployedPool = CREATEX.deployCreate2(
      _salt(_deployer, _SIMPLE_POOL_SALT), abi.encodePacked(type(PrivacyPoolSimple).creationCode, _constructorArgs)
    );

    _pool = PrivacyPoolSimple(_deployedPool);
  }

  /**
   * @dev Deploys a Complex Privacy Pool for ERC20 tokens
   * @param _deployer Address of the deployer used for salt generation
   * @param _entrypoint Address of the Entrypoint contract
   * @param _withdrawalVerifier Address of the Withdrawal Verifier contract
   * @param _commitmentVerifier Address of the Commitment Verifier contract
   * @param _asset Address of the ERC20 token to be used in the pool
   * @return _pool The deployed Complex Privacy Pool contract
   */
  function deployComplexPool(
    address _deployer,
    address _entrypoint,
    address _withdrawalVerifier,
    address _commitmentVerifier,
    address _asset
  ) public returns (PrivacyPoolComplex _pool) {
    bytes memory _constructorArgs = abi.encode(_entrypoint, _withdrawalVerifier, _commitmentVerifier, _asset);

    address _deployedPool = CREATEX.deployCreate2(
      _salt(_deployer, _COMPLEX_POOL_SALT), abi.encodePacked(type(PrivacyPoolComplex).creationCode, _constructorArgs)
    );

    _pool = PrivacyPoolComplex(_deployedPool);
  }

  /**
   * @dev Deploys a Commitment Verifier contract
   * @param _deployer Address of the deployer used for salt generation
   * @return _verifier The deployed Commitment Verifier contract
   * @notice This function uses RAGEQUIT_VERIFIER_SALT despite deploying a CommitmentVerifier
   */
  function deployCommitmentVerifier(address _deployer) public returns (CommitmentVerifier _verifier) {
    _verifier = CommitmentVerifier(
      CREATEX.deployCreate2(
        _salt(_deployer, _RAGEQUIT_VERIFIER_SALT), abi.encodePacked(type(CommitmentVerifier).creationCode)
      )
    );
  }

  /**
   * @dev Deploys a Withdrawal Verifier contract
   * @param _deployer Address of the deployer used for salt generation
   * @return _verifier The deployed Withdrawal Verifier contract
   */
  function deployWithdrawalVerifier(address _deployer) public returns (WithdrawalVerifier _verifier) {
    _verifier = WithdrawalVerifier(
      CREATEX.deployCreate2(
        _salt(_deployer, _WITHDRAWAL_VERIFIER_SALT), abi.encodePacked(type(WithdrawalVerifier).creationCode)
      )
    );
  }

  /**
   * @dev Creates a custom salt for deterministic deployments
   * @param _deployer Address of the deployer
   * @param _custom Custom salt value
   * @return _customSalt The generated salt
   */
  function _salt(address _deployer, bytes11 _custom) internal pure returns (bytes32 _customSalt) {
    return bytes32(abi.encodePacked(_deployer, hex'00', _custom));
  }
}
