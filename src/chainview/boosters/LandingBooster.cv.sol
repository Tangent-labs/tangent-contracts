// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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
    struct LandingBoosterOut {
        uint256[] amounts;
    }
    error LandingBoosterError(LandingBoosterOut output);

    address public cvgCvxstaking = 0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119;

    constructor(address[] memory lpAssets) {
        // TODO  supply USG , supply sUSG , prix sUSG , [ apy USG  => API ]

        // TODO  apy RSTAN  , supply locked RSTAN , price RSTAN

        uint256[] memory boosterTvl = getBoosterTvl(lpAssets);
        LandingBoosterOut memory output = LandingBoosterOut({amounts: boosterTvl});
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
