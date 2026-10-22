// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC4626, IERC20} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IAggregatorStablePriceV3} from "../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";

struct USGInfoOut {
    uint256 circulatingUsg;
    uint256 UsgPrice;
    uint256 sUsgSupply;
    uint256 usgStakedOnSgUsd;
}
abstract contract UsgInfo {
    function getUSGInfo(IERC20 usg, IERC4626 sUSG, address[] memory pegKeepers, IAggregatorStablePriceV3 usgOracle) public returns (USGInfoOut memory info) {
        // 1. Supply of USG (excluding pegKeepers)
        uint256 totalSupply = usg.totalSupply();
        uint256 totalPegKeeperBalance = 0;

        for (uint256 i = 0; i < pegKeepers.length; i++) {
            totalPegKeeperBalance += usg.balanceOf(pegKeepers[i]);
        }

        info.circulatingUsg = totalSupply - totalPegKeeperBalance;

        // 2. USG Price
        info.UsgPrice = usgOracle.price_w();

        // 3. Supply of sUSG
        info.sUsgSupply = sUSG.totalSupply() - sUSG.balanceOf(address(sUSG));

        // 4. Amount of tgUSD staked on sUSG
        info.usgStakedOnSgUsd = sUSG.totalAssets();
    }
}
