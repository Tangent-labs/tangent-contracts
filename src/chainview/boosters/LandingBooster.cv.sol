// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../TgUsdInfoLib.sol";
import "../RsTanDataLib.sol";

interface IStakingPositionService {
    struct CycleInfo {
        uint256 cvgRewardsAmount;
        uint256 totalStaked;
        bool isCvxProcessed;
    }
    function stakingCycle() external view returns (uint256);
    function cycleInfo(uint256 cycle) external view returns (CycleInfo memory);
}

contract LandingBooster {
    struct LandingBoosterIn {
        address tgUSD;
        address tgUSDOracle;
        address pegKeeperTgUSD_USDC;
        address pegKeeperTgUSD_frxUSD;
        address sgUSD;
        address rsTan;
        address tanPool;
    }

    struct LandingBoosterOut {
        uint256[] boosterAmounts;
        uint256[] tgSudAmounts;
        uint256[] rsTanSudAmounts;
    }
    error LandingBoosterError(LandingBoosterOut output);

    address public constant cvgCvxstaking = 0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119;
    address public constant CHAINLINK_ETH_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    constructor(address[] memory lpAssets, LandingBoosterIn memory input) {
        // Store input parameters

        // TODO  supply USG , supply sUSG , prix sUSG , [ apy USG  => API ]
        TgUsdInfoLib.TgUsdInfo memory tgSudInfo = TgUsdInfoLib.getTgUsdInfo(input.tgUSD, input.tgUSDOracle, input.pegKeeperTgUSD_USDC, input.pegKeeperTgUSD_frxUSD, input.sgUSD);
        uint256[] memory tgSudAmounts = new uint256[](4);
        tgSudAmounts[0] = tgSudInfo.circulatingTgUsd;
        tgSudAmounts[1] = tgSudInfo.tgUsdPrice;
        tgSudAmounts[2] = tgSudInfo.sgUsdSupply;
        tgSudAmounts[3] = tgSudInfo.tgUsdStakedOnSgUsd;

        // TODO  apy RSTAN  , supply locked RSTAN , price RSTAN
        RsTanDataLib.RsTanData memory rsTanSudInfo = RsTanDataLib.getRsTanData(input.rsTan, input.tanPool, input.tgUSD, CHAINLINK_ETH_ORACLE);
        uint256[] memory rsTanSudAmounts = new uint256[](4);
        rsTanSudAmounts[0] = rsTanSudInfo.tanPrice;
        rsTanSudAmounts[1] = rsTanSudInfo.totalSupplyRsTan;
        rsTanSudAmounts[2] = rsTanSudInfo.rewardRate;
        rsTanSudAmounts[3] = rsTanSudInfo.apr;

        uint256[] memory boosterTvl = getBoosterTvl(lpAssets);
        LandingBoosterOut memory output = LandingBoosterOut({boosterAmounts: boosterTvl, tgSudAmounts: tgSudAmounts, rsTanSudAmounts: rsTanSudAmounts});
        revert LandingBoosterError(output);
    }

    /*
     * @notice Get the total amount of token  of the booster (Stake DAO + Convex)
     * @return Array of token amounts of the booster
     */
    function getBoosterTvl(address[] memory lpAssets) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](lpAssets.length + 1);

        // Get the stake DAO part
        uint256 i = 0;
        for (i; i < lpAssets.length; i++) {
            IStakingPositionService sdtService = IStakingPositionService(lpAssets[i]);
            uint256 cycle = sdtService.stakingCycle();
            amounts[i] = sdtService.cycleInfo(cycle + 1).totalStaked;
        }

        // Get the Convex part
        IStakingPositionService cvgCvxPositionService = IStakingPositionService(cvgCvxstaking);
        uint256 currentCycle = cvgCvxPositionService.stakingCycle();
        amounts[i] = cvgCvxPositionService.cycleInfo(currentCycle + 1).totalStaked;

        return amounts;
    }
}
