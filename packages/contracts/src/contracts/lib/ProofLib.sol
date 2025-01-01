// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// TODO: once proof is defined, update proof body and indices
library ProofLib {
  struct Proof {
    uint256[2] pA;
    uint256[2][2] pB;
    uint256[2] pC;
    uint256[20] pubSignals;
  }

  function stateRoot(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[0];
  }

  function ASPRoot(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[1];
  }

  function existingNullifierHash(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[2];
  }

  function withdrawnAmount(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[3];
  }

  function scope(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[5];
  }

  function context(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[6];
  }

  function newCommitmentHash(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[7];
  }

  function value(Proof memory _p) public pure returns (uint256) {
    return _p.pubSignals[8];
  }
}
