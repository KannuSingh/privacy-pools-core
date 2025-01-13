// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Poseidon} from 'contracts/lib/Poseidon.sol';

import {Test} from 'forge-std/Test.sol';
import {IPoseidonT2, IPoseidonT3, IPoseidonT4} from 'interfaces/IPoseidon.sol';

import {PoseidonT2} from 'poseidon/PoseidonT2.sol';
import {PoseidonT3} from 'poseidon/PoseidonT3.sol';
import {PoseidonT4} from 'poseidon/PoseidonT4.sol';

/**
 * @notice Tests for the Poseidon hashing contracts
 * @dev The Poseidon contracts were generated using https://github.com/iden3/circomlibjs
 * @dev The values we're asserting against were generated using the Poseidon WASM implementation from circomlibjs
 */
contract UnitPoseidonT2 is Test {
  IPoseidonT2 internal _poseidon;

  function setUp() public {
    _poseidon = Poseidon.deployT2();
    assertTrue(address(_poseidon) != address(0));
  }

  function test_hashUint() public view {
    assertEq(_poseidon.poseidon([uint256(1)]), PoseidonT2.hash([uint256(1)]));

    assertEq(_poseidon.poseidon([uint256(2)]), PoseidonT2.hash([uint256(2)]));

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_random_value'))]),
      PoseidonT2.hash([uint256(keccak256('some_random_value'))])
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_other_random_value'))]),
      PoseidonT2.hash([uint256(keccak256('some_other_random_value'))])
    );
  }
}

contract UnitPoseidonT3 is Test {
  IPoseidonT3 internal _poseidon;

  function setUp() public {
    _poseidon = Poseidon.deployT3();
    assertTrue(address(_poseidon) != address(0));
  }

  function test_hashUint() public view {
    assertEq(_poseidon.poseidon([uint256(1), uint256(2)]), PoseidonT3.hash([uint256(1), uint256(2)]));

    assertEq(_poseidon.poseidon([uint256(4), uint256(5)]), PoseidonT3.hash([uint256(4), uint256(5)]));

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_random_value')), uint256(keccak256('some_other_random_value'))]),
      PoseidonT3.hash([uint256(keccak256('some_random_value')), uint256(keccak256('some_other_random_value'))])
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_other_random_value')), uint256(keccak256('some_random_value'))]),
      PoseidonT3.hash([uint256(keccak256('some_other_random_value')), uint256(keccak256('some_random_value'))])
    );
  }
}

contract UnitPoseidonT4 is Test {
  IPoseidonT4 internal _poseidon;

  function setUp() public {
    _poseidon = Poseidon.deployT4();
    assertTrue(address(_poseidon) != address(0));
  }

  function test_hashUint() public view {
    assertEq(
      _poseidon.poseidon([uint256(1), uint256(2), uint256(3)]), PoseidonT4.hash([uint256(1), uint256(2), uint256(3)])
    );

    assertEq(
      _poseidon.poseidon([uint256(4), uint256(5), uint256(6)]), PoseidonT4.hash([uint256(4), uint256(5), uint256(6)])
    );

    assertEq(
      _poseidon.poseidon(
        [
          uint256(keccak256('some_random_value')),
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript'))
        ]
      ),
      PoseidonT4.hash(
        [
          uint256(keccak256('some_random_value')),
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript'))
        ]
      )
    );

    assertEq(
      _poseidon.poseidon(
        [
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript')),
          uint256(keccak256('some_random_value'))
        ]
      ),
      PoseidonT4.hash(
        [
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript')),
          uint256(keccak256('some_random_value'))
        ]
      )
    );
  }
}
