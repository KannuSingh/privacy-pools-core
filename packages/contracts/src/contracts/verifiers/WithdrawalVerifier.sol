// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract WithdrawalVerifier {
  // Scalar field size
  uint256 constant r =
    21_888_242_871_839_275_222_246_405_745_257_275_088_548_364_400_416_034_343_698_204_186_575_808_495_617;
  // Base field size
  uint256 constant q =
    21_888_242_871_839_275_222_246_405_745_257_275_088_696_311_157_297_823_662_689_037_894_645_226_208_583;

  // Verification Key data
  uint256 constant alphax =
    20_491_192_805_390_485_299_153_009_773_594_534_940_189_261_866_228_447_918_068_658_471_970_481_763_042;
  uint256 constant alphay =
    9_383_485_363_053_290_200_918_347_156_157_836_566_562_967_994_039_712_273_449_902_621_266_178_545_958;
  uint256 constant betax1 =
    4_252_822_878_758_300_859_123_897_981_450_591_353_533_073_413_197_771_768_651_442_665_752_259_397_132;
  uint256 constant betax2 =
    6_375_614_351_688_725_206_403_948_262_868_962_793_625_744_043_794_305_715_222_011_528_459_656_738_731;
  uint256 constant betay1 =
    21_847_035_105_528_745_403_288_232_691_147_584_728_191_162_732_299_865_338_377_159_692_350_059_136_679;
  uint256 constant betay2 =
    10_505_242_626_370_262_277_552_901_082_094_356_697_409_835_680_220_590_971_873_171_140_371_331_206_856;
  uint256 constant gammax1 =
    11_559_732_032_986_387_107_991_004_021_392_285_783_925_812_861_821_192_530_917_403_151_452_391_805_634;
  uint256 constant gammax2 =
    10_857_046_999_023_057_135_944_570_762_232_829_481_370_756_359_578_518_086_990_519_993_285_655_852_781;
  uint256 constant gammay1 =
    4_082_367_875_863_433_681_332_203_403_145_435_568_316_851_327_593_401_208_105_741_076_214_120_093_531;
  uint256 constant gammay2 =
    8_495_653_923_123_431_417_604_973_247_489_272_438_418_190_587_263_600_148_770_280_649_306_958_101_930;
  uint256 constant deltax1 =
    5_101_597_244_350_902_433_884_322_636_911_728_027_755_108_462_744_357_774_920_088_302_991_139_465_590;
  uint256 constant deltax2 =
    19_693_919_659_217_571_144_377_343_643_307_001_469_796_988_322_805_048_476_785_491_401_112_761_759_739;
  uint256 constant deltay1 =
    12_278_129_925_984_918_843_866_376_487_446_587_556_019_495_152_278_714_741_203_951_201_143_692_150_656;
  uint256 constant deltay2 =
    7_381_938_079_202_356_459_215_769_894_481_363_111_554_881_792_164_521_288_691_121_794_566_942_286_579;

  uint256 constant IC0x =
    16_148_105_666_203_862_965_387_243_430_225_407_356_287_196_650_373_131_595_365_027_485_816_037_911_900;
  uint256 constant IC0y =
    21_615_999_052_313_154_850_676_241_963_688_611_364_836_973_439_873_693_563_306_467_457_098_331_348_075;

  uint256 constant IC1x =
    13_145_575_450_193_874_255_316_306_319_665_855_572_081_997_698_715_275_916_849_447_632_401_357_731_446;
  uint256 constant IC1y =
    836_555_222_908_457_845_696_763_107_154_346_624_346_976_089_850_656_490_257_701_631_525_889_114_385;

  uint256 constant IC2x =
    12_197_059_349_166_431_138_974_724_303_199_033_482_190_301_571_498_851_877_111_391_687_392_381_195_938;
  uint256 constant IC2y =
    1_704_894_320_554_507_498_525_100_014_672_209_992_480_806_357_828_605_226_631_630_626_990_149_408_930;

  uint256 constant IC3x =
    8_141_178_413_351_457_415_236_084_158_729_394_386_655_825_437_906_411_531_082_832_498_448_646_901_965;
  uint256 constant IC3y =
    19_675_363_546_413_908_975_713_823_178_218_347_287_890_421_074_308_842_936_807_928_595_768_076_605_294;

  uint256 constant IC4x =
    17_196_499_179_582_027_891_027_942_246_916_949_026_674_374_136_496_617_673_383_760_431_730_596_474_777;
  uint256 constant IC4y =
    14_185_028_421_073_691_544_218_669_605_491_722_641_238_899_407_551_894_132_621_880_121_511_633_035_697;

  uint256 constant IC5x =
    15_853_666_281_260_790_343_165_712_171_318_466_701_136_105_451_825_808_258_033_647_267_174_901_848_674;
  uint256 constant IC5y =
    21_420_391_690_239_444_554_758_117_369_313_724_729_296_932_815_825_154_131_342_135_686_052_632_329_084;

  uint256 constant IC6x =
    20_905_875_728_535_335_560_111_169_781_316_626_779_771_582_606_165_666_956_375_053_368_850_040_930_925;
  uint256 constant IC6y =
    1_688_518_663_540_369_383_776_258_717_136_261_524_008_125_744_624_227_835_394_113_982_007_174_060_864;

  uint256 constant IC7x =
    20_359_757_871_341_498_030_337_754_636_881_606_593_312_684_640_209_296_683_737_491_828_747_418_197_565;
  uint256 constant IC7y =
    16_371_639_775_566_752_906_308_030_676_980_270_689_441_600_748_725_204_364_165_649_296_308_947_022_577;

  uint256 constant IC8x =
    10_429_481_242_244_695_482_713_271_321_701_054_592_036_939_456_843_231_359_193_097_479_769_782_286_309;
  uint256 constant IC8y =
    16_754_892_134_667_431_672_126_588_122_554_824_110_691_553_913_084_171_094_432_716_687_358_411_650_715;

  // Memory data
  uint16 constant pVk = 0;
  uint16 constant pPairing = 128;

  uint16 constant pLastMem = 896;

  function verifyProof(
    uint256[2] calldata _pA,
    uint256[2][2] calldata _pB,
    uint256[2] calldata _pC,
    uint256[8] calldata _pubSignals
  ) public view returns (bool) {
    assembly {
      function checkField(v) {
        if iszero(lt(v, r)) {
          mstore(0, 0)
          return(0, 0x20)
        }
      }

      // G1 function to multiply a G1 value(x,y) to value in an address
      function g1_mulAccC(pR, x, y, s) {
        let success
        let mIn := mload(0x40)
        mstore(mIn, x)
        mstore(add(mIn, 32), y)
        mstore(add(mIn, 64), s)

        success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

        if iszero(success) {
          mstore(0, 0)
          return(0, 0x20)
        }

        mstore(add(mIn, 64), mload(pR))
        mstore(add(mIn, 96), mload(add(pR, 32)))

        success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

        if iszero(success) {
          mstore(0, 0)
          return(0, 0x20)
        }
      }

      function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
        let _pPairing := add(pMem, pPairing)
        let _pVk := add(pMem, pVk)

        mstore(_pVk, IC0x)
        mstore(add(_pVk, 32), IC0y)

        // Compute the linear combination vk_x

        g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))

        g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))

        g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))

        g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))

        g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))

        g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))

        g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))

        g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))

        // -A
        mstore(_pPairing, calldataload(pA))
        mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

        // B
        mstore(add(_pPairing, 64), calldataload(pB))
        mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
        mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
        mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

        // alpha1
        mstore(add(_pPairing, 192), alphax)
        mstore(add(_pPairing, 224), alphay)

        // beta2
        mstore(add(_pPairing, 256), betax1)
        mstore(add(_pPairing, 288), betax2)
        mstore(add(_pPairing, 320), betay1)
        mstore(add(_pPairing, 352), betay2)

        // vk_x
        mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
        mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

        // gamma2
        mstore(add(_pPairing, 448), gammax1)
        mstore(add(_pPairing, 480), gammax2)
        mstore(add(_pPairing, 512), gammay1)
        mstore(add(_pPairing, 544), gammay2)

        // C
        mstore(add(_pPairing, 576), calldataload(pC))
        mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

        // delta2
        mstore(add(_pPairing, 640), deltax1)
        mstore(add(_pPairing, 672), deltax2)
        mstore(add(_pPairing, 704), deltay1)
        mstore(add(_pPairing, 736), deltay2)

        let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

        isOk := and(success, mload(_pPairing))
      }

      let pMem := mload(0x40)
      mstore(0x40, add(pMem, pLastMem))

      // Validate that all evaluations ∈ F

      checkField(calldataload(add(_pubSignals, 0)))

      checkField(calldataload(add(_pubSignals, 32)))

      checkField(calldataload(add(_pubSignals, 64)))

      checkField(calldataload(add(_pubSignals, 96)))

      checkField(calldataload(add(_pubSignals, 128)))

      checkField(calldataload(add(_pubSignals, 160)))

      checkField(calldataload(add(_pubSignals, 192)))

      checkField(calldataload(add(_pubSignals, 224)))

      // Validate all evaluations
      let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

      mstore(0, isValid)
      return(0, 0x20)
    }
  }
}
