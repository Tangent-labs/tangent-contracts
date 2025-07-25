// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IUSG {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IsUSG {
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
}

interface IAggregatorStablePriceV3 {
    function price_w() external returns (uint256);
}

abstract contract USGInfo {
    struct USGInfoData {
        uint256 circulatingUsg;
        uint256 UsgPrice;
        uint256 sUsgSupply;
        uint256 usgStakedOnSgUsd;
        uint256 sUsgPrice;
    }

    function getUSGInfo(address usgAddress, address usgOracleAddress, address[] memory pegKeepers, address sgUSDAddress) public  returns (USGInfoData memory info) {
        // 1. Supply of USG (excluding pegKeepers)
        IUSG usg = IUSG(usgAddress);
        uint256 totalSupply = usg.totalSupply();
        uint256 totalPegKeeperBalance = 0;

        for (uint256 i = 0; i < pegKeepers.length; i++) {
            totalPegKeeperBalance += usg.balanceOf(pegKeepers[i]);
        }

        info.circulatingUsg = totalSupply - totalPegKeeperBalance;

        // 2. USG Price
        IAggregatorStablePriceV3 usgOracle = IAggregatorStablePriceV3(usgOracleAddress);
        info.UsgPrice = usgOracle.price_w(); // revert No reason

        // 3. Supply of sgUSD
        IsUSG sgUSD = IsUSG(sgUSDAddress);
        info.sUsgSupply = sgUSD.totalSupply();

        // 4. Amount of tgUSD staked on sgUSD
        info.usgStakedOnSgUsd = sgUSD.totalAssets();

        // 5. Price of sUSG
        if (info.usgStakedOnSgUsd > 0) {
            uint256 sUsgAssets = sgUSD.convertToAssets(1 ether);
            info.sUsgPrice = (sUsgAssets * info.UsgPrice) / 1e18;
        } else {
            info.sUsgPrice = 0;
        }
    }
}
