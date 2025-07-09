// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITgUSD {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface ITsgUSD {
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IAggregatorStablePriceV3 {
    function price_w() external view returns (uint256);
}

abstract contract TgUsdInfoLib {
    struct TgUsdInfo {
        uint256 circulatingTgUsd;
        uint256 tgUsdPrice;
        uint256 sgUsdSupply;
        uint256 tgUsdStakedOnSgUsd;
    }

    function getTgUsdInfo(address tgUSDAddress, address tgUSDOracleAddress, address[] memory pegKeepers, address sgUSDAddress) public view returns (TgUsdInfo memory info) {
        // 1. Supply of tgUSD (excluding pegKeepers)
        ITgUSD tgUSD = ITgUSD(tgUSDAddress);
        uint256 totalSupply = tgUSD.totalSupply();
        uint256 totalPegKeeperBalance = 0;

        for (uint256 i = 0; i < pegKeepers.length; i++) {
            totalPegKeeperBalance += tgUSD.balanceOf(pegKeepers[i]);
        }

        info.circulatingTgUsd = totalSupply - totalPegKeeperBalance;

        // 2. tgUSD Price
        IAggregatorStablePriceV3 tgUSDOracle = IAggregatorStablePriceV3(tgUSDOracleAddress);
        info.tgUsdPrice = tgUSDOracle.price_w();

        // 3. Supply of sgUSD
        ITsgUSD sgUSD = ITsgUSD(sgUSDAddress);
        info.sgUsdSupply = sgUSD.totalSupply();

        // 4. Amount of tgUSD staked on sgUSD
        info.tgUsdStakedOnSgUsd = sgUSD.totalAssets();
    }
}
