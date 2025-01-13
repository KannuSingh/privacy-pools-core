// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPrivacyPoolComplex, PrivacyPoolComplex} from 'contracts/implementations/PrivacyPoolComplex.sol';
import {Test} from 'forge-std/Test.sol';

import {IERC20} from '@oz/token/ERC20/IERC20.sol';
import {IPrivacyPool} from 'interfaces/IPrivacyPool.sol';

/**
 * @notice Test contract for the PrivacyPoolComplex
 */
contract ComplexPoolForTest is PrivacyPoolComplex {
  constructor(
    address _entrypoint,
    address _verifier,
    address _asset
  ) PrivacyPoolComplex(_entrypoint, _verifier, _asset) {}

  function pull(address _sender, uint256 _amount) external payable {
    _pull(_sender, _amount);
  }

  function push(address _recipient, uint256 _amount) external {
    _push(_recipient, _amount);
  }
}

/**
 * @notice Base test contract for the PrivacyPoolComplex
 */
contract UnitPrivacyPoolComplex is Test {
  ComplexPoolForTest internal _pool;
  uint256 internal _scope;

  address internal immutable _ENTRYPOINT = makeAddr('entrypoint');
  address internal immutable _VERIFIER = makeAddr('verifier');
  address internal immutable _ASSET = makeAddr('asset');

  /*//////////////////////////////////////////////////////////////
                            SETUP
  //////////////////////////////////////////////////////////////*/

  function setUp() public {
    _pool = new ComplexPoolForTest(_ENTRYPOINT, _VERIFIER, _ASSET);
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
contract UnitConstructor is UnitPrivacyPoolComplex {
  /**
   * @notice Test for the constructor given valid addresses
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorGivenValidAddresses(address _entrypoint, address _verifier, address _asset) external {
    vm.assume(_entrypoint != address(0) && _verifier != address(0) && _asset != address(0));

    _pool = new ComplexPoolForTest(_entrypoint, _verifier, _asset);
    _scope = uint256(keccak256(abi.encodePacked(address(_pool), block.chainid, _asset)));
    assertEq(address(_pool.ENTRYPOINT()), _entrypoint);
    assertEq(address(_pool.VERIFIER()), _verifier);
    assertEq(_pool.ASSET(), _asset);
    assertEq(_pool.SCOPE(), _scope);
  }

  /**
   * @notice Test for the constructor when any address is zero
   * @dev Assumes all addresses are non-zero and valid
   */
  function test_ConstructorWhenAnyAddressIsZero(address _entrypoint, address _verifier, address _asset) external {
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new ComplexPoolForTest(address(0), _verifier, _asset);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new ComplexPoolForTest(_entrypoint, address(0), _asset);
    vm.expectRevert(IPrivacyPool.ZeroAddress.selector);
    new ComplexPoolForTest(_entrypoint, _verifier, address(0));
  }
}

contract UnitPull is UnitPrivacyPoolComplex {
  function test_Pull(address _sender, uint256 _amount) external {
    vm.assume(_sender != address(0));
    vm.assume(_amount > 0);

    // Mock transfer
    _mockAndExpect(
      _ASSET, abi.encodeWithSelector(IERC20.transferFrom.selector, _sender, address(_pool), _amount), abi.encode(true)
    );

    // Execute
    vm.prank(_sender);
    _pool.pull(_sender, _amount);
  }

  function test_PullWhenMsgValueNotZero(address _sender, uint256 _amount) external {
    vm.assume(_sender != address(0));
    vm.assume(_amount > 0);

    deal(address(_sender), _amount);

    vm.expectRevert(IPrivacyPoolComplex.NativeAssetNotAccepted.selector);
    vm.prank(_sender);
    _pool.pull{value: _amount}(_sender, _amount);
  }
}

contract UnitPush is UnitPrivacyPoolComplex {
  function test_Push(address _recipient, uint256 _amount) external {
    vm.assume(_amount > 0);
    vm.assume(_recipient != address(0));

    // Mock transfer
    _mockAndExpect(_ASSET, abi.encodeWithSelector(IERC20.transfer.selector, _recipient, _amount), abi.encode(true));

    // Execute
    vm.prank(_recipient);
    _pool.push(_recipient, _amount);
  }
}
