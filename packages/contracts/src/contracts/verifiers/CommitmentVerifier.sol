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

contract CommitmentVerifier {
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
    14_071_349_277_984_160_738_769_650_232_570_048_842_420_599_174_481_891_079_570_637_520_850_148_195_985;
  uint256 constant deltax2 =
    21_776_852_187_814_503_669_288_941_195_438_703_300_133_533_055_551_110_414_135_507_755_772_009_048_755;
  uint256 constant deltay1 =
    17_768_817_325_504_614_104_442_767_796_226_297_300_876_042_529_701_251_019_410_487_903_768_062_418_156;
  uint256 constant deltay2 =
    14_829_896_038_465_638_754_619_183_039_629_777_804_281_009_075_842_360_651_276_603_555_963_792_313_589;

  uint256 constant IC0x =
    19_389_685_603_863_983_493_459_600_466_245_000_912_176_323_935_722_089_191_442_216_924_893_875_659_471;
  uint256 constant IC0y =
    21_368_310_947_604_120_084_615_976_168_620_713_319_957_912_144_314_383_367_152_441_982_584_687_704_754;

  uint256 constant IC1x =
    20_480_370_908_727_861_268_768_811_690_351_970_824_724_320_271_007_139_967_515_539_994_552_383_745_448;
  uint256 constant IC1y =
    6_543_788_534_290_546_924_704_177_190_532_160_218_635_019_071_447_323_280_686_282_609_769_447_108_534;

  uint256 constant IC2x =
    6_221_997_045_242_061_390_626_775_825_094_098_886_891_157_777_390_462_309_437_733_708_122_892_686_303;
  uint256 constant IC2y =
    2_977_171_917_149_158_683_110_905_238_240_269_877_054_732_203_916_711_132_834_349_252_293_157_981_665;

  uint256 constant IC3x =
    17_383_678_627_611_548_606_682_427_983_617_497_767_432_126_302_933_563_182_026_534_678_391_392_668_921;
  uint256 constant IC3y =
    3_215_629_258_564_266_791_517_073_142_612_182_991_488_671_524_212_271_597_007_691_057_737_644_736_842;

  uint256 constant IC4x =
    8_279_881_556_386_467_131_443_125_483_794_142_587_933_910_369_215_858_657_040_335_636_659_378_561_647;
  uint256 constant IC4y =
    13_829_047_140_424_789_745_087_385_395_711_127_297_752_590_615_995_160_902_909_738_061_982_036_826_097;

  // Memory data
  uint16 constant pVk = 0;
  uint16 constant pPairing = 128;

  uint16 constant pLastMem = 896;

  function verifyProof(
    uint256[2] calldata _pA,
    uint256[2][2] calldata _pB,
    uint256[2] calldata _pC,
    uint256[4] calldata _pubSignals
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

      // Validate all evaluations
      let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

      mstore(0, isValid)
      return(0, 0x20)
    }
  }
}
