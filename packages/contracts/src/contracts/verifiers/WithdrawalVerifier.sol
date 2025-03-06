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
    16_428_432_848_801_857_252_194_528_405_604_668_803_277_877_773_566_238_944_394_625_302_971_855_135_431;
  uint256 constant alphay =
    16_846_502_678_714_586_896_801_519_656_441_059_708_016_666_274_385_668_027_902_869_494_772_365_009_666;
  uint256 constant betax1 =
    3_182_164_110_458_002_340_215_786_955_198_810_119_980_427_837_186_618_912_744_689_678_939_861_918_171;
  uint256 constant betax2 =
    16_348_171_800_823_588_416_173_124_589_066_524_623_406_261_996_681_292_662_100_840_445_103_873_053_252;
  uint256 constant betay1 =
    4_920_802_715_848_186_258_981_584_729_175_884_379_674_325_733_638_798_907_835_771_393_452_862_684_714;
  uint256 constant betay2 =
    19_687_132_236_965_066_906_216_944_365_591_810_874_384_658_708_175_106_803_089_633_851_114_028_275_753;
  uint256 constant gammax1 =
    11_559_732_032_986_387_107_991_004_021_392_285_783_925_812_861_821_192_530_917_403_151_452_391_805_634;
  uint256 constant gammax2 =
    10_857_046_999_023_057_135_944_570_762_232_829_481_370_756_359_578_518_086_990_519_993_285_655_852_781;
  uint256 constant gammay1 =
    4_082_367_875_863_433_681_332_203_403_145_435_568_316_851_327_593_401_208_105_741_076_214_120_093_531;
  uint256 constant gammay2 =
    8_495_653_923_123_431_417_604_973_247_489_272_438_418_190_587_263_600_148_770_280_649_306_958_101_930;
  uint256 constant deltax1 =
    355_730_187_017_390_060_257_088_699_243_557_931_444_743_893_437_609_284_639_879_195_946_356_391_671;
  uint256 constant deltax2 =
    11_377_546_232_269_146_885_719_711_323_617_440_487_334_358_631_817_944_307_305_954_377_320_021_081_609;
  uint256 constant deltay1 =
    14_828_571_047_823_507_951_936_654_719_331_566_168_682_863_576_761_372_686_128_260_593_891_040_163_007;
  uint256 constant deltay2 =
    14_925_671_126_934_765_953_425_446_845_541_707_408_298_799_882_358_491_896_288_696_759_849_089_416_456;

  uint256 constant IC0x =
    20_917_852_783_971_662_989_037_834_579_922_189_207_796_850_157_455_689_196_836_407_829_693_273_058_181;
  uint256 constant IC0y =
    14_309_172_700_509_163_829_827_835_936_087_829_189_193_823_544_006_124_999_667_589_607_573_555_153_317;

  uint256 constant IC1x =
    4_002_318_554_163_308_338_961_115_195_600_756_325_669_504_095_744_400_749_661_836_505_711_747_131_480;
  uint256 constant IC1y =
    19_388_553_801_400_869_339_697_580_180_794_985_615_392_396_320_851_212_290_435_880_306_887_322_433_262;

  uint256 constant IC2x =
    4_254_123_736_274_716_305_094_004_322_466_639_736_349_000_292_613_093_104_635_160_011_340_821_139_688;
  uint256 constant IC2y =
    19_581_123_507_269_704_428_735_684_612_376_263_280_905_609_143_077_051_758_684_797_548_075_203_355_862;

  uint256 constant IC3x =
    12_829_149_822_163_537_636_941_647_022_474_968_478_908_625_676_617_259_064_999_683_111_486_877_280_191;
  uint256 constant IC3y =
    11_906_986_527_782_177_454_913_261_933_143_777_359_684_553_833_291_705_890_148_735_374_364_062_300_950;

  uint256 constant IC4x =
    14_959_519_196_996_577_022_953_934_863_461_427_249_996_916_985_368_164_934_760_550_902_108_247_251_314;
  uint256 constant IC4y =
    17_153_998_018_818_455_451_015_682_095_753_537_372_058_398_415_644_924_731_407_055_981_674_255_991_568;

  uint256 constant IC5x =
    386_592_992_276_936_501_107_132_673_378_759_567_169_940_445_750_810_516_666_781_824_566_579_325_489;
  uint256 constant IC5y =
    6_545_363_418_535_856_048_783_449_340_812_901_581_000_301_323_807_547_677_423_370_106_415_935_030_419;

  uint256 constant IC6x =
    14_405_334_651_179_970_829_248_032_802_453_416_652_902_403_107_461_697_011_217_734_903_378_819_167_500;
  uint256 constant IC6y =
    5_941_867_495_000_526_980_426_755_384_727_509_338_287_954_936_978_959_436_019_043_816_230_884_260_430;

  uint256 constant IC7x =
    6_593_325_309_923_573_421_969_784_559_603_844_408_437_482_353_554_868_263_039_840_702_125_354_704_945;
  uint256 constant IC7y =
    19_710_681_365_262_161_445_645_108_505_967_116_609_968_223_704_683_705_865_914_938_644_210_040_221_046;

  uint256 constant IC8x =
    13_832_774_438_085_654_502_815_602_896_317_109_691_851_791_928_314_457_690_314_578_958_243_235_503_172;
  uint256 constant IC8y =
    2_034_154_171_145_211_628_085_643_224_823_864_015_412_822_036_123_513_499_722_451_852_634_747_199_812;

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
