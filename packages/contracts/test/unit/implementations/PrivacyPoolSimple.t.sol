// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPrivacyPoolSimple, PrivacyPoolSimple} from 'contracts/implementations/PrivacyPoolSimple.sol';
import {Test} from 'forge-std/Test.sol';

import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @notice Test contract for the PrivacyPoolSimple
 */
contract SimplePoolForTest is PrivacyPoolSimple {
  constructor(
    address _entrypoint,
    address _verifier,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) PrivacyPoolSimple(_entrypoint, _verifier, _poseidonT2, _poseidonT3, _poseidonT4) {}

  function pull(address _sender, uint256 _amount) external payable {
    _pull(_sender, _amount);
  }

  function push(address _recipient, uint256 _amount) external {
    _push(_recipient, _amount);
  }
}

/**
 * @notice Base test contract for the PrivacyPoolSimple
 */
contract UnitPrivacyPoolSimple is Test {
  SimplePoolForTest internal _pool;
  uint256 internal _scope;

  address internal immutable _ENTRYPOINT = makeAddr('entrypoint');
  address internal immutable _VERIFIER = makeAddr('verifier');
  address internal immutable _ASSET = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address internal immutable _POSEIDON_T2 = makeAddr('poseidonT2');
  address internal immutable _POSEIDON_T3 = makeAddr('poseidonT3');
  address internal immutable _POSEIDON_T4 = makeAddr('poseidonT4');

  /*//////////////////////////////////////////////////////////////
                            SETUP
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    _pool = new SimplePoolForTest(_ENTRYPOINT, _VERIFIER, _POSEIDON_T2, _POSEIDON_T3, _POSEIDON_T4);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _ASSET)));
  }

  /*//////////////////////////////////////////////////////////////
                            HELPERS
  //////////////////////////////////////////////////////////////*/

  function _mockAndExpect(address _contract, bytes memory _call, bytes memory _return) internal {
    vm.mockCall(_contract, _call, _return);
    vm.expectCall(_contract, _call);
  }
}

/**
 * @notice Unit tests for the constructor
 */
contract UnitConstructor is UnitPrivacyPoolSimple {
  /**
   * @notice Test for the constructor given valid addresses
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorGivenValidAddresses(
    address _entrypoint,
    address _verifier,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) external {
    vm.assume(
      _entrypoint != address(0) && _verifier != address(0) && _poseidonT2 != address(0) && _poseidonT3 != address(0)
        && _poseidonT4 != address(0)
    );

    _pool = new SimplePoolForTest(_entrypoint, _verifier, _poseidonT2, _poseidonT3, _poseidonT4);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _ASSET)));
    assertEq(address(_pool.ENTRYPOINT()), _entrypoint);
    assertEq(address(_pool.VERIFIER()), _verifier);
    assertEq(_pool.ASSET(), _ASSET);
    assertEq(_pool.SCOPE(), _scope);
    assertEq(address(_pool.POSEIDON_T2()), _poseidonT2);
    assertEq(address(_pool.POSEIDON_T3()), _poseidonT3);
    assertEq(address(_pool.POSEIDON_T4()), _poseidonT4);
  }

  /**
   * @notice Test for the constructor when any address is zero
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorWhenAnyAddressIsZero(
    address _entrypoint,
    address _verifier,
    address _poseidonT2,
    address _poseidonT3,
    address _poseidonT4
  ) external {
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new SimplePoolForTest(address(0), _verifier, _poseidonT2, _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new SimplePoolForTest(_entrypoint, address(0), _poseidonT2, _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new SimplePoolForTest(_entrypoint, _verifier, address(0), _poseidonT3, _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new SimplePoolForTest(_entrypoint, _verifier, _poseidonT2, address(0), _poseidonT4);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new SimplePoolForTest(_entrypoint, _verifier, _poseidonT2, _poseidonT3, address(0));
  }
}

contract UnitPull is UnitPrivacyPoolSimple {
  function test_Pull(address _sender, uint256 _amount) external {
    vm.assume(_sender != address(_pool)); // Add this

    // Setup
    deal(_sender, _amount);
    uint256 _senderInitialBalance = _sender.balance;
    uint256 _poolInitialBalance = address(_pool).balance;

    // Execution
    vm.prank(_sender);
    _pool.pull{value: _amount}(_sender, _amount);

    // Assertions
    assertEq(address(_pool).balance, _poolInitialBalance + _amount);
    assertEq(_sender.balance, _senderInitialBalance - _amount);
  }

  function test_PullWhenAmountIsGreaterThanMsgValue(address _sender, uint256 _amount, uint256 _msgValue) external {
    vm.assume(_amount > 0);
    deal(_sender, _amount);
    _msgValue = bound(_msgValue, 0, _amount - 1);
    vm.expectRevert(IPrivacyPoolSimple.InsufficientValue.selector);
    vm.prank(_sender);
    _pool.pull{value: _msgValue}(_sender, _amount);
  }
}

contract UnitPush is UnitPrivacyPoolSimple {
  function test_Push(address _recipient, uint256 _amount) external {
    vm.assume(_amount > 0);
    // avoid precompiles
    vm.assume(_recipient > address(10) && _recipient.code.length == 0);

    // Setup
    deal(address(_pool), _amount);
    uint256 _poolInitialBalance = address(_pool).balance;
    uint256 _recipientInitialBalance = _recipient.balance;

    // Execution
    vm.prank(_recipient);
    _pool.push(_recipient, _amount);

    // Assertions
    assertEq(address(_pool).balance, _poolInitialBalance - _amount);
    assertEq(_recipient.balance, _recipientInitialBalance + _amount);
  }

  function test_PushWhenTransferFails(address _recipient, uint256 _amount) external {
    vm.assume(_recipient > address(10));
    vm.assume(_recipient != address(_pool));
    vm.assume(_amount > 0);

    // Deploy reverting contract at recipient address
    bytes memory revertingCode = hex'60006000fd'; // PUSH1 0x00 PUSH1 0x00 REVERT
    vm.etch(_recipient, revertingCode);

    vm.expectRevert(IPrivacyPoolSimple.FailedToSendETH.selector);

    deal(address(_pool), _amount);
    _pool.push(_recipient, _amount);
  }
}
