// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IVsTan} from "../interfaces/internals/USG/IVsTan.sol";
import {Reward} from "../interfaces/internals/USG/IRewardAccumulator.sol";

import {ICurveCryptoSwap} from "../interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {IAggregatorV3} from "../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IAggregatorStablePriceV3} from "../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";

abstract contract VsTANInfo {
    struct RsTanData {
        uint256 tanPrice;
        uint256 totalSupplyVsTan;
        uint256 rewardRate;
        uint256 apr;
    }
    function getVsTanInfo(IVsTan vsTan, ICurveCryptoSwap tanLP, IERC20 usg, IAggregatorV3 ethOracle, IAggregatorStablePriceV3 usgOracle) public returns (RsTanData memory data) {
        uint256 ethPrice = ethOracle.latestAnswer() * 10 ** (ethOracle.decimals());

        // TAN price
        uint256 tanPriceInEth = 0;
        if (address(tanLP) != address(0)) {
            tanPriceInEth = tanLP.last_prices();
        }
        data.tanPrice = (tanPriceInEth * 1e18) / ethPrice;

        // Amount of TAN locked on rsTAN
        data.totalSupplyVsTan = vsTan.totalSupplyVsTan();

        Reward memory reward = vsTan.getRewardData(usg);

        uint256 usgPrice = usgOracle.price_w();
        uint256 expectedYearlyDistribution = reward.periodFinish < block.timestamp ? 0 : ((reward.rewardRate * 365 days * usgPrice) / 1e18); // rewardRate * 1 year

        uint256 tvl = (data.totalSupplyVsTan * data.tanPrice) / 1e18; // totalAmountLocked * tanPrice
        if (tvl > 0) {
            data.apr = (expectedYearlyDistribution * 1e18) / tvl; // APR with 18 decimals
        } else {
            data.apr = 0;
        }
    }
}
