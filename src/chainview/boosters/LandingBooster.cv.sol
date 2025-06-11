// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ISdtStakingViewer {
    struct SdAssetGlobalView {
        address gaugeAsset;
        address sdAsset;
        address asset;
        address stakingAddress;
        uint256 cvgCycle;
        uint256 previousTotal;
        uint256 actualTotal;
        uint256 nextTotal;
    }
}

interface IGlobalViewSdAssetStaking {
    function getGlobalViewSdAssetStaking(address[] calldata stakingContracts) external view returns (ISdtStakingViewer.SdAssetGlobalView[] memory);
}

interface ICvxStakingPositionService {
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

    address public SdtStakingViewer = 0xA3A8cDA21f50b6737385E46FC9495a9998B05Ff0;
    address public cvgCvxstaking = 0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119;
    address public cvgCVX = 0x2191DF768ad71140F9F3E96c1e4407A4aA31d082;

    constructor(address[] memory lpAssets) {
        uint256[] memory boosterTvl = getBoosterTvl(lpAssets);
        LandingBoosterOut memory output = LandingBoosterOut({amounts: boosterTvl});
        revert LandingBoosterError(output);
    }

    /*
     * @notice Get the total TVL of the booster (Stake DAO + Convex)
     * @return totalTvl The total TVL of the booster
     */
    function getBoosterTvl(address[] memory lpAssets) public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](lpAssets.length + 1);

        // Get the stake DAO part
        ISdtStakingViewer.SdAssetGlobalView[] memory sdAssetGlobalView = IGlobalViewSdAssetStaking(SdtStakingViewer).getGlobalViewSdAssetStaking(lpAssets);
        uint256 i = 0;
        for (i; i < sdAssetGlobalView.length; i++) {
            amounts[i] = sdAssetGlobalView[i].actualTotal;
        }

        // Get the Convex part
        ICvxStakingPositionService staking = ICvxStakingPositionService(cvgCvxstaking);
        uint256 currentCycle = staking.stakingCycle();
        amounts[i] = staking.cycleInfo(currentCycle + 1).totalStaked;

        return amounts;
    }
}
