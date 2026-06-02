// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../contexts/MarketDeploymentContext.sol";
import {TokenAmount} from "../../../src/interfaces/internals/ICommonStruct.sol";
import {ConvexAPR, ConvexAPRData} from "../../../src/chainview/USG/bot/ConvexAPR.cv.sol";

contract ConvexAPRChainviewTest is MarketDeploymentContext {
    address private constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address private constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;

    function setUp() public {
        vm.createSelectFork("mainnet", 25092979);
    }

    function test_convexAPR_returns() public {
        uint256[] memory pids = new uint256[](2);
        pids[0] = 541;
        pids[1] = 542;

        try new ConvexAPR(pids) {} catch (bytes memory reason) {
            ConvexAPRData[] memory result = abi.decode(removeFirst4Bytes(reason), (ConvexAPRData[]));

            assertEq(result.length, 2);
            assertEq(result[0].pid, 541);
            assertEq(result[1].pid, 542);

            console.log("Convex APR data:");
            for (uint256 i; i < result.length; i++) {
                console.log("pid", result[i].pid);
         
                assertGt(result[i].yearlyRewardPerLp.length, 0);

                console.log("yearly reward per LP and current reward vAPR:");
                for (uint256 j; j < result[i].yearlyRewardPerLp.length; j++) {
                    TokenAmount memory reward = result[i].yearlyRewardPerLp[j];
                    //assertGt(reward.amount, 0, "Yearly reward per LP should not be zero");
                    console.log("reward token");
                    console.logAddress(address(reward.token));
                    console.log("yearly reward per 1e18 LP", reward.amount);
                    uint256 apr = _rewardApr(address(reward.token), reward.amount);
                    console.log("reward APR 1e18", apr);
                    console.log("reward APR percent 1e18", apr * 100);
                }
            }
        }
    }

    function _rewardApr(address rewardToken, uint256 yearlyRewardPerLp) internal pure returns (uint256) {
        uint256 rewardPrice;
        if (rewardToken == CRV) rewardPrice = 265_000_000_000_000_000; // 0.265 USD, example price.
        if (rewardToken == CVX) rewardPrice = 2_950_000_000_000_000_000; // 2.95 USD, example price.
        if (rewardPrice == 0) return 0;

        uint256 lpPrice = 1e18;
        return (yearlyRewardPerLp * rewardPrice) / lpPrice;
    }
}
