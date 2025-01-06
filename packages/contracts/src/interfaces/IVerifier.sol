// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ProofLib} from '../contracts/lib/ProofLib.sol';

interface IVerifier {
  function verifyProof(ProofLib.Proof memory _proof) external returns (bool);
}
