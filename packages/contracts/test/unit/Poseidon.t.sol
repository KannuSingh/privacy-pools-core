// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Poseidon} from 'contracts/lib/Poseidon.sol';

import {Test} from 'forge-std/Test.sol';
import {IPoseidonT2, IPoseidonT3, IPoseidonT4} from 'interfaces/IPoseidon.sol';

// TODO: fuzz hashing values?

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
    assertEq(
      _poseidon.poseidon([uint256(1)]),
      18_586_133_768_512_220_936_620_570_745_912_940_619_677_854_269_274_689_475_585_506_675_881_198_879_027
    );

    assertEq(
      _poseidon.poseidon([uint256(2)]),
      8_645_981_980_787_649_023_086_883_978_738_420_856_660_271_013_038_108_762_834_452_721_572_614_684_349
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_random_value'))]),
      15_698_786_858_573_585_361_515_994_629_112_950_716_024_935_072_492_224_257_175_753_399_957_674_789_960
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_other_random_value'))]),
      19_630_650_487_847_892_557_238_854_367_994_219_388_158_732_755_497_846_985_854_020_753_559_372_872_102
    );
  }

  function test_hashBytes32() public view {
    assertEq(
      _poseidon.poseidon([bytes32(uint256(1))]),
      bytes32(
        uint256(18_586_133_768_512_220_936_620_570_745_912_940_619_677_854_269_274_689_475_585_506_675_881_198_879_027)
      )
    );

    assertEq(
      _poseidon.poseidon([bytes32(uint256(2))]),
      bytes32(
        uint256(8_645_981_980_787_649_023_086_883_978_738_420_856_660_271_013_038_108_762_834_452_721_572_614_684_349)
      )
    );

    assertEq(
      _poseidon.poseidon([keccak256('some_random_value')]),
      bytes32(
        uint256(15_698_786_858_573_585_361_515_994_629_112_950_716_024_935_072_492_224_257_175_753_399_957_674_789_960)
      )
    );

    assertEq(
      _poseidon.poseidon([keccak256('some_other_random_value')]),
      bytes32(
        uint256(19_630_650_487_847_892_557_238_854_367_994_219_388_158_732_755_497_846_985_854_020_753_559_372_872_102)
      )
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
    assertEq(
      _poseidon.poseidon([uint256(1), uint256(2)]),
      7_853_200_120_776_062_878_684_798_364_095_072_458_815_029_376_092_732_009_249_414_926_327_459_813_530
    );

    assertEq(
      _poseidon.poseidon([uint256(4), uint256(5)]),
      756_592_041_685_769_348_226_045_093_946_546_956_867_261_766_023_639_881_791_475_046_640_232_555_043
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_random_value')), uint256(keccak256('some_other_random_value'))]),
      274_031_838_051_346_471_085_058_200_733_143_912_855_023_384_699_344_963_446_236_290_214_042_572_320
    );

    assertEq(
      _poseidon.poseidon([uint256(keccak256('some_other_random_value')), uint256(keccak256('some_random_value'))]),
      10_702_074_020_250_145_060_338_707_724_195_605_695_284_283_569_324_674_178_498_942_050_913_095_096_399
    );
  }

  function test_hashBytes32() public view {
    assertEq(
      _poseidon.poseidon([bytes32(uint256(1)), bytes32(uint256(2))]),
      bytes32(
        uint256(7_853_200_120_776_062_878_684_798_364_095_072_458_815_029_376_092_732_009_249_414_926_327_459_813_530)
      )
    );

    assertEq(
      _poseidon.poseidon([bytes32(uint256(4)), bytes32(uint256(5))]),
      bytes32(
        uint256(756_592_041_685_769_348_226_045_093_946_546_956_867_261_766_023_639_881_791_475_046_640_232_555_043)
      )
    );

    assertEq(
      _poseidon.poseidon([keccak256('some_random_value'), keccak256('some_other_random_value')]),
      bytes32(
        uint256(274_031_838_051_346_471_085_058_200_733_143_912_855_023_384_699_344_963_446_236_290_214_042_572_320)
      )
    );

    assertEq(
      _poseidon.poseidon([keccak256('some_other_random_value'), keccak256('some_random_value')]),
      bytes32(
        uint256(10_702_074_020_250_145_060_338_707_724_195_605_695_284_283_569_324_674_178_498_942_050_913_095_096_399)
      )
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
      _poseidon.poseidon([uint256(1), uint256(2), uint256(3)]),
      6_542_985_608_222_806_190_361_240_322_586_112_750_744_169_038_454_362_455_181_422_643_027_100_751_666
    );

    assertEq(
      _poseidon.poseidon([uint256(4), uint256(5), uint256(6)]),
      13_068_585_895_974_403_773_725_650_933_384_448_557_830_349_138_894_291_742_480_310_149_013_072_346_139
    );

    assertEq(
      _poseidon.poseidon(
        [
          uint256(keccak256('some_random_value')),
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript'))
        ]
      ),
      9_398_014_232_372_129_441_242_579_454_898_292_743_220_172_821_071_740_868_915_067_406_726_216_275_952
    );

    assertEq(
      _poseidon.poseidon(
        [
          uint256(keccak256('some_other_random_value')),
          uint256(keccak256('please_no_more_javascript')),
          uint256(keccak256('some_random_value'))
        ]
      ),
      1_045_601_628_524_649_433_066_831_145_813_031_537_586_249_631_080_908_459_123_837_663_957_790_297_889
    );
  }

  function test_hashBytes32() public view {
    assertEq(
      _poseidon.poseidon([bytes32(uint256(1)), bytes32(uint256(2)), bytes32(uint256(3))]),
      bytes32(
        uint256(6_542_985_608_222_806_190_361_240_322_586_112_750_744_169_038_454_362_455_181_422_643_027_100_751_666)
      )
    );

    assertEq(
      _poseidon.poseidon([bytes32(uint256(4)), bytes32(uint256(5)), bytes32(uint256(6))]),
      bytes32(
        uint256(13_068_585_895_974_403_773_725_650_933_384_448_557_830_349_138_894_291_742_480_310_149_013_072_346_139)
      )
    );

    assertEq(
      _poseidon.poseidon(
        [keccak256('some_random_value'), keccak256('some_other_random_value'), keccak256('please_no_more_javascript')]
      ),
      bytes32(
        uint256(9_398_014_232_372_129_441_242_579_454_898_292_743_220_172_821_071_740_868_915_067_406_726_216_275_952)
      )
    );

    assertEq(
      _poseidon.poseidon(
        [keccak256('some_other_random_value'), keccak256('please_no_more_javascript'), keccak256('some_random_value')]
      ),
      bytes32(
        uint256(1_045_601_628_524_649_433_066_831_145_813_031_537_586_249_631_080_908_459_123_837_663_957_790_297_889)
      )
    );
  }
}
