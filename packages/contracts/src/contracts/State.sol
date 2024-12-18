// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {InternalLeanIMT, LeanIMTData} from "lean-imt/InternalLeanIMT.sol";
import {ProofLib} from "./lib/ProofLib.sol";
import {IERC20} from "@oz/interfaces/IERC20.sol";

interface IEntrypoint {
    function getLatestRoot() external returns (uint256);
}

interface IVerifier {
    function verifyProof(ProofLib.Proof memory _proof) external returns (bool);
}

abstract contract State {
    using InternalLeanIMT for LeanIMTData;

    uint256 public immutable SCOPE;
    IEntrypoint public immutable ENTRYPOINT;
    IVerifier public immutable VERIFIER;
    IERC20 public immutable ASSET;
    address private immutable _POSEIDON;
    bool public dead;
    string public constant version = "0.1.0";

    LeanIMTData internal merkleTree;

    constructor(
        address _entrypoint,
        address _verifier,
        address _asset,
        address _poseidon
    ) {
        ENTRYPOINT = IEntrypoint(_entrypoint);
        VERIFIER = IVerifier(_verifier);
        ASSET = IERC20(_asset);
        _POSEIDON = _poseidon;

        SCOPE = uint256(
            keccak256(abi.encodePacked(address(this), block.chainid, _asset))
        );
    }

    error NotEntrypoint();
    error PoolIsDead();

    modifier onlyEntrypoint() {
        require(msg.sender == address(ENTRYPOINT), NotEntrypoint());
        _;
    }

    function _spend(uint256 _nullifierHash) internal {
        merkleTree._insert(_nullifierHash);
    }

    function _insert(uint256 _root) internal {
        merkleTree._insert(_root);
    }

    function _isInState(uint256 _leaf) internal view returns (bool) {
        return merkleTree._has(_leaf);
    }

    function _isKnownRoot(uint256 _root) internal returns (bool) {}
}
