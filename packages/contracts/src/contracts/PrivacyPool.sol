// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {State} from "./State.sol";
import {ProofLib} from "./lib/ProofLib.sol";

abstract contract PrivacyPool is State {
    using ProofLib for ProofLib.Proof;

    event Deposited();
    event PoolDied();
    event Ragequit();
    event Withdrawn();

    error InvalidCommitment();
    error InvalidNullifier();
    error InvalidProcesooor();

    struct Withdrawal {
        address procesooor;
        bytes data;
    }

    constructor(
        address _entrypoint,
        address _verifier,
        address _asset,
        address _poseidon
    ) State(_entrypoint, _verifier, _asset, _poseidon) {}

    // only callable by entrypoint
    function deposit(
        address _depositor,
        uint256 _value,
        uint256 _nullifierHash
    ) external payable onlyEntrypoint returns (uint256 _commitmentHash) {
        // check deposits are enabled
        require(!dead, PoolIsDead());

        // compute commitment hash
        _commitmentHash = uint256(
            keccak256(
                abi.encodePacked(
                    SCOPE,
                    _depositor,
                    _value,
                    uint256(0),
                    _nullifierHash
                )
            )
        );

        // insert commitment in state (revert if already present)
        _insert(_commitmentHash);

        // check if nullifier was already used by another commitment
        if (_isInState(_nullifierHash)) {
            revert InvalidNullifier();
        }

        // pull funds from depositor
        _handleValueInput(msg.sender, _value);

        // emit event
        emit Deposited();
    }

    modifier validWithdrawal(Withdrawal memory _w, ProofLib.Proof memory _p) {
        require(msg.sender == _w.procesooor, InvalidProcesooor());
        require(_p.scope() == SCOPE);
        require(_p.context() == uint256(keccak256(abi.encode(_w, SCOPE))));
        require(!_isInState(_p.nullifierHash()));
        require(_isKnownRoot(_p.stateRoot()));
        require(_p.ASPRoot() == ENTRYPOINT.getLatestRoot());
        _;
    }

    function withdraw(
        Withdrawal memory _w,
        ProofLib.Proof memory _p
    ) external validWithdrawal(_w, _p) {
        // verify proof with Groth16 verifier
        VERIFIER.verifyProof(_p);

        // spend nullifier
        _spend(_p.nullifierHash());
        // insert new commitment in state
        _insert(_p.newCommitmentHash());

        // transfer out funds to procesooor
        _handleValueOutput(_w.procesooor, _p.value());

        // emit event
        emit Withdrawn();
    }

    function ragequit(
        uint256 _value,
        uint256 _nullifierHash,
        uint256 _parentHash
    ) external {
        // compute commitment hash using caller address
        uint256 _commitmentHash = uint256(
            keccak256(
                abi.encodePacked(
                    SCOPE,
                    msg.sender,
                    _value,
                    _parentHash,
                    _nullifierHash
                )
            )
        );

        // check commitment exists in state and has not been spent yet
        if (!_isInState(_commitmentHash) || _isInState(_nullifierHash)) {
            revert InvalidCommitment();
        }

        // spend commitment
        _spend(_nullifierHash);

        // transfer funds to caller
        _handleValueOutput(msg.sender, _value);

        // emit event
        emit Ragequit();
    }

    // only callable by entrypoint
    function windDown() external onlyEntrypoint {
        // check pool is alive
        require(!dead, PoolIsDead());
        // die
        dead = true;

        // emit event
        emit PoolDied();
    }

    // virtual method to override in asset specific implementations
    function _handleValueInput(
        address _sender,
        uint256 _value
    ) internal virtual;

    // virtual method to override in asset specific implementations
    function _handleValueOutput(
        address _recipient,
        uint256 _value
    ) internal virtual;
}
