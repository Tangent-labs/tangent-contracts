 // // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
// import "../../../interfaces/internals/USG/IPriceOracle.sol";

// import {OracleBase} from "../OracleBase.sol";

// contract OracleTriPoolStable is OracleBase {
//     struct OracleTriPoolStruct {
//         IPriceOracle coin0Oracle;
//         uint96 coin0OracleDecimals;
//         IPriceOracle coin1Oracle;
//         uint96 coin1OracleDecimals;
//         IPriceOracle coin2Oracle;
//         uint96 coin2OracleDecimals;
//         ICurveStableSwapNG lp;
//     }
//     OracleTriPoolStruct public params;

//     constructor(address _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle, IPriceOracle _coin2Oracle) {
//         params = OracleTriPoolStruct({
//             coin0Oracle: _coin0Oracle,
//             coin1Oracle: _coin1Oracle,
//             coin2Oracle: _coin2Oracle,
//             lp: ICurveStableSwapNG(_lp),
//             coin0OracleDecimals: uint96(_coin0Oracle.decimals()),
//             coin1OracleDecimals: uint96(_coin1Oracle.decimals()),
//             coin2OracleDecimals: uint96(_coin2Oracle.decimals())
//         });
//     }

//     function min(uint256 a, uint256 b) internal pure returns (uint256) {
//         if (a > b) {
//             return b;
//         }
//         return a;
//     }

//     function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
//         OracleTriPoolStruct memory _params = params;
//         uint256 answer0 = _params.coin0Oracle.latestAnswer(isNoFailMode);
//         uint256 answer1 = _params.coin1Oracle.latestAnswer(isNoFailMode);
//         uint256 answer2 = _params.coin2Oracle.latestAnswer(isNoFailMode);

//         return (_params.lp.get_virtual_price() * min(answer0, min(answer1, answer2))) / 10 ** 18;
//     }

//     function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
//         OracleTriPoolStruct memory _params = params;
//         uint256 answer0 = _params.coin0Oracle.latestAnswerUpdate(isNoFailMode);
//         uint256 answer1 = _params.coin1Oracle.latestAnswerUpdate(isNoFailMode);
//         uint256 answer2 = _params.coin2Oracle.latestAnswerUpdate(isNoFailMode);

//         return (_params.lp.get_virtual_price() * min(answer0, min(answer1, answer2))) / 10 ** 18;
//     }
// }
