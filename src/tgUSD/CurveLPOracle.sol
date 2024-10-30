// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/externals/Curve/ICurveStableSwapNG.sol";

contract CurveLPOracle {
    mapping(address => uint256) curveLPType;

    ICurveStableSwapNG lp = ICurveStableSwapNG(0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7);

    function getLPPrice(address curveLP) external view returns (uint256) {
        return lp.get_dy(1, 0, 1 ether);
    }
}
