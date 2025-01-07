// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ProofLib
 * @notice Facilitates accessing the public signals of a Groth16 proof.
 */
library ProofLib {

  /**
   * @notice Semantic version of the library
   */
  string constant VERSION = '0.1.0';

  /**
   * @notice Struct containing Groth16 proof elements and public signals for withdrawal verification
   * @dev The public signals array must match the order of public inputs/outputs in the circuit
   * @param pA First elliptic curve point (π_A) of the Groth16 proof, encoded as two field elements
   * @param pB Second elliptic curve point (π_B) of the Groth16 proof, encoded as 2x2 matrix of field elements
   * @param pC Third elliptic curve point (π_C) of the Groth16 proof, encoded as two field elements
   * @param pubSignals Array of public inputs and outputs:
   *        - [0] withdrawnValue: Amount being withdrawn
   *        - [1] stateRoot: Current state root of the privacy pool
   *        - [2] stateTreeDepth: Current depth of the state tree
   *        - [3] ASPRoot: Current root of the Association Set Provider tree
   *        - [4] ASPTreeDepth: Current depth of the ASP tree
   *        - [5] context: Context value for the withdrawal operation
   *        - [6] existingNullifierHash: Hash of the nullifier being spent
   *        - [7] newCommitmentHash: Hash of the new commitment being created
   */
  struct Proof {
    uint256[2] pA;
    uint256[2][2] pB;
    uint256[2] pC;
    uint256[8] pubSignals;
  }

  /**
   * @notice Retrieves the withdrawn value from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The amount being withdrawn from Privacy Pool
   */
  function withdrawnValue(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[0];
  }

  /**
   * @notice Retrieves the state root from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The root of the state tree at time of proof generation
   */
  function stateRoot(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[1];
  }

  /**
   * @notice Retrieves the state tree depth from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The depth of the state tree at time of proof generation
   */
  function stateTreeDepth(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[2];
  }

  /**
   * @notice Retrieves the ASP root from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The latest root of the ASP tree at time of proof generation
   */
  function ASPRoot(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[3];
  }

  /**
   * @notice Retrieves the ASP tree depth from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The depth of the ASP tree at time of proof generation
   */
  function ASPTreeDepth(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[4];
  }

  /**
   * @notice Retrieves the context value from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The context value binding the proof to specific withdrawal data
   */
  function context(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[5];
  }

  /**
   * @notice Retrieves the existing nullifier hash from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The hash of the nullifier being spent in this withdrawal
   */
  function existingNullifierHash(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[6];
  }

  /**
   * @notice Retrieves the new commitment hash from the proof's public signals
   * @param _p The proof containing the public signals
   * @return The hash of the new commitment being created
   */
  function newCommitmentHash(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[7];
  }
}

