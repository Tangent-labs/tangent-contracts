// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IChainlinkOracle {
    function latestAnswer() external view returns (uint256);
}

interface ITanPool {
    function last_prices() external view returns (uint256);
}

interface IRsTan {
    function totalAssets() external view returns (uint256);
    function totalSupplyRsTan() external view returns (uint256);
    function rewardData(address token) external view returns (Reward memory);
}

struct Reward {
    uint256 rewardRate;
    uint256 periodFinish;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
}

library RsTanDataLib {
    struct RsTanData {
        uint256 tanPrice;
        uint256 totalSupplyRsTan;
        uint256 rewardRate;
        uint256 apr;
    }
    function getRsTanData(
        address rsTanAddress,
        address tanPoolAddress,
        address tgUSDAddress,
        address chainlinkEthOracleAddress
    ) public view returns (RsTanDataLib.RsTanData memory data) {
        IChainlinkOracle ethOracle = IChainlinkOracle(chainlinkEthOracleAddress);
        uint256 ethPrice = ethOracle.latestAnswer();

        // 1. TAN price
        uint256 tanPriceInEth = 0;
        if (tanPoolAddress != address(0)) {
            ITanPool tanPool = ITanPool(tanPoolAddress);
            tanPriceInEth = tanPool.last_prices();
        }
        data.tanPrice = (tanPriceInEth * 1e18) / ethPrice;

        // 2. Amount of TAN locked on rsTAN
        IRsTan rsTan = IRsTan(rsTanAddress);
        data.totalSupplyRsTan = rsTan.totalSupplyRsTan();

        // 3. Amount of tgUSD distributed per second
        Reward memory reward = rsTan.rewardData(tgUSDAddress);
        data.rewardRate = reward.rewardRate;

        // 4. rsTAN APR
        // Note: The original calculation referenced results[4] and results[6], which do not exist in the new struct-based approach.
        // We'll use totalSupplyRsTan and tanPrice for TVL, and reward.rewardRate for yearly distribution.
        uint256 expectedYearlyDistribution = reward.rewardRate * 365 days; // rewardRate * 1 year
        uint256 tvl = data.totalSupplyRsTan * data.tanPrice; // totalAmountLocked * tanPrice
        if (tvl > 0) {
            data.apr = (expectedYearlyDistribution * 1e18) / tvl; // APR with 18 decimals
        } else {
            data.apr = 0;
        }
    }
}
