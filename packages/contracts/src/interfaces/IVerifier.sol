// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IVerifier {
  function verifyProof(
    uint256[2] memory pA,
    uint256[2][2] memory pB,
    uint256[2] memory pC,
    uint256[8] memory pubSignals
  ) external returns (bool);

  function verifyProof(
    uint256[2] memory pA,
    uint256[2][2] memory pB,
    uint256[2] memory pC,
    uint256[5] memory pubSignals
  ) external returns (bool);
}
