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

// NOTE: this contract was generated using the Hermez Rollup precalculated Powers of Tau. This contract MUST be used for testing purposes only.

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
    73_712_057_753_386_887_278_787_400_600_421_166_257_337_249_383_532_897_612_755_159_051_862_588_716;
  uint256 constant deltax2 =
    17_838_259_529_838_485_406_872_362_261_336_315_588_259_651_695_147_656_151_175_887_183_766_663_167_227;
  uint256 constant deltay1 =
    21_572_110_967_738_371_130_980_582_612_407_141_022_569_080_033_980_241_905_689_742_698_493_693_902_211;
  uint256 constant deltay2 =
    14_911_365_522_566_990_301_624_399_798_135_221_704_649_796_655_110_277_593_879_804_468_224_218_648_506;

  uint256 constant IC0x =
    5_954_542_358_255_226_704_823_440_350_389_128_520_840_961_859_578_816_778_653_916_076_718_164_954_104;
  uint256 constant IC0y =
    19_478_395_007_811_459_164_170_849_967_888_067_954_284_420_107_659_112_447_936_045_222_877_478_028_155;

  uint256 constant IC1x =
    939_520_433_615_386_846_870_643_004_591_111_759_679_015_179_059_721_411_620_955_194_578_600_993_879;
  uint256 constant IC1y =
    4_991_377_186_889_934_987_629_778_707_116_655_924_149_800_597_008_638_344_870_092_051_698_616_234_377;

  uint256 constant IC2x =
    16_145_213_852_524_552_938_188_684_173_645_767_259_267_129_310_114_283_025_265_612_363_129_636_337_154;
  uint256 constant IC2y =
    1_732_644_168_740_351_316_705_303_020_323_916_501_386_116_681_305_849_042_542_231_584_469_362_168_236;

  uint256 constant IC3x =
    2_258_528_467_553_052_712_961_117_170_854_449_667_778_207_554_104_324_380_823_554_459_635_162_933_545;
  uint256 constant IC3y =
    12_958_740_285_017_492_819_350_216_519_755_841_600_711_746_193_375_371_473_558_800_660_618_436_286_056;

  uint256 constant IC4x =
    1_925_927_471_867_228_937_013_962_243_578_213_724_467_692_336_440_215_495_910_789_299_557_077_186_516;
  uint256 constant IC4y =
    1_246_082_004_897_931_361_756_161_407_296_959_950_757_107_649_506_399_500_667_544_802_177_634_617_908;

  uint256 constant IC5x =
    11_717_413_929_857_745_557_982_679_405_518_390_945_320_339_872_499_163_630_629_788_499_563_043_191_005;
  uint256 constant IC5y =
    11_483_972_396_989_937_739_184_056_642_564_126_144_908_636_894_112_522_377_039_849_814_271_376_124_053;

  uint256 constant IC6x =
    11_607_850_068_490_217_106_666_683_734_746_776_347_209_394_379_159_393_725_655_587_615_781_457_665_206;
  uint256 constant IC6y =
    747_087_201_271_795_988_402_939_765_727_764_258_216_303_748_245_613_568_229_095_116_667_725_404_376;

  uint256 constant IC7x =
    19_550_498_529_930_412_297_816_357_469_077_337_760_543_868_054_322_680_790_981_748_131_589_104_041_567;
  uint256 constant IC7y =
    21_777_276_686_705_049_677_287_388_189_947_468_972_292_284_605_441_887_434_437_559_325_455_370_788_399;

  uint256 constant IC8x =
    12_198_206_262_149_507_623_604_983_338_587_544_617_689_590_556_233_050_651_320_145_320_400_790_229_732;
  uint256 constant IC8y =
    1_793_573_329_756_085_905_829_978_158_980_596_904_214_513_348_911_192_851_332_607_510_223_915_335_586;

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

