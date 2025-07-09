// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../TgUsdInfoLib.sol";
import "../RsTanDataLib.sol";

interface ICurvePool {
    function get_dy(
        int128 i, //index tokenIn
        int128 j, //index tokenOut
        uint256 dx //amountIn
    ) external view returns (uint256);
}

interface IStakingPositionService {
    struct CycleInfo {
        uint256 cvgRewardsAmount;
        uint256 totalStaked;
        bool isCvxProcessed;
    }
    function stakingCycle() external view returns (uint256);
    function cycleInfo(uint256 cycle) external view returns (CycleInfo memory);
}

contract LandingBooster is TgUsdInfoLib, RsTanDataLib {
    struct LandingBoosterIn {
        address tgUSD;
        address tgUSDOracle;
        address[] pegKeepers;
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
    address public constant cvgCvxCvx1Pool = 0xc50E191F703FB3160fC15d8b168A8c740fec3666;

    constructor(address[] memory lpAssets, LandingBoosterIn memory input) {
        // Store input parameters

        // TODO  supply USG , supply sUSG , prix sUSG , [ apy USG  => API ]
        TgUsdInfo memory tgSudInfo = getTgUsdInfo(input.tgUSD, input.tgUSDOracle, input.pegKeepers, input.sgUSD);
        uint256[] memory tgSudAmounts = new uint256[](4);
        tgSudAmounts[0] = tgSudInfo.circulatingTgUsd;
        tgSudAmounts[1] = tgSudInfo.tgUsdPrice;
        tgSudAmounts[2] = tgSudInfo.sgUsdSupply;
        tgSudAmounts[3] = tgSudInfo.tgUsdStakedOnSgUsd;

        // TODO  apy RSTAN  , supply locked RSTAN , price RSTAN
        RsTanData memory rsTanSudInfo = getRsTanData(input.rsTan, input.tanPool, input.tgUSD, CHAINLINK_ETH_ORACLE);
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
        uint256 totalStaked = cvgCvxPositionService.cycleInfo(currentCycle + 1).totalStaked;

        // check the CVX1 amount ( pegged 1:1 to CVX )
        ICurvePool cvgCvxCvx1PoolContract = ICurvePool(cvgCvxCvx1Pool);
        uint256 peggedCvxAmount = cvgCvxCvx1PoolContract.get_dy(1, 0, 1 ether);
        amounts[i] = (peggedCvxAmount * totalStaked) / 1 ether; // CVX amount

        return amounts;
    }
}
