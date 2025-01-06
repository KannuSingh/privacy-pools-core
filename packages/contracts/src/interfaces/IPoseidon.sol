// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IPoseidonT2
 * @notice Interface for the IPoseidonT2 contract
 */
interface IPoseidonT2 {
  /**
   * @notice Compute the Poseidon hash for a bytes32 input
   * @param _input The bytes32 input
   * @return _hash The computed hash
   */
  function poseidon(bytes32[1] memory _input) external pure returns (bytes32 _hash);

  /**
   * @notice Compute the Poseidon hash for a uint256 input
   * @param _input The uint256 input
   * @return _hash The computed hash
   */
  function poseidon(uint256[1] memory _input) external pure returns (uint256 _hash);
}

/**
 * @title IPoseidonT3
 * @notice Interface for the IPoseidonT3 contract
 */
interface IPoseidonT3 {
  /**
   * @notice Compute the Poseidon hash for two bytes32 inputs
   * @param _input The bytes32 inputs
   * @return _hash The computed hash
   */
  function poseidon(bytes32[2] memory _input) external pure returns (bytes32 _hash);

  /**
   * @notice Compute the Poseidon hash for two uint256 inputs
   * @param _input The uint256 inputs
   * @return _hash The computed hash
   */
  function poseidon(uint256[2] memory _input) external pure returns (uint256 _hash);
}

/**
 * @title IPoseidonT4
 * @notice Interface for the IPoseidonT4 contract
 */
interface IPoseidonT4 {
  /**
   * @notice Compute the Poseidon hash for three bytes32 inputs
   * @param _input The bytes32 inputs
   * @return _hash The computed hash
   */
  function poseidon(bytes32[3] memory _input) external pure returns (bytes32 _hash);

  /**
   * @notice Compute the Poseidon hash for three uint256 inputs
   * @param _input The uint256 inputs
   * @return _hash The computed hash
   */
  function poseidon(uint256[3] memory _input) external pure returns (uint256 _hash);
}
