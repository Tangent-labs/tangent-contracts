// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../UsgInfo.sol";
import "../VsTANInfo.sol";

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

contract LandingChainView is UsgInfo, VsTANInfo {
    error LandingChainViewError(uint256[] output);

    // Booster addresses
    address public constant cvgCvxStaking = 0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119;
    address public constant cvgCvxCvx1Pool = 0xc50E191F703FB3160fC15d8b168A8c740fec3666;

    address public constant cvgSdtPool = 0xC6628f00F29cc89a87BBeE7554C4725611200fD7;
    address public constant cvgSdtStaking = 0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933;
    address public constant sdCrvStaking = 0x2FF160bcADb485b5F048b9880e6f471Af632060c;
    address public constant sdPendleStaking = 0x508f0E1b565b40AeB94671BeD228083203330882;
    address public constant sdFxnStaking = 0x35e30Bc815935Bb5EC1743f772331864D780cc26;
    address public constant sdBalStaking = 0xAf5b3f4A0b4dc334dB7137E5584E0e971E5e4962;
    address public constant cvgSdtStaking = 0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933;
    address public constant cvgSdtPool = 0xC6628f00F29cc89a87BBeE7554C4725611200fD7;

    // USG/TAN addresses
    address public constant usg = address(0);
    address public constant usgOracle = address(0);
    address public constant sUSG = address(0);
    address public constant tan = address(0);
    address public constant tanPool = address(0);

    function getKeepers() internal pure returns (address[] memory) {
        address[] memory pegKeepers = new address[](0);
        return pegKeepers;
    }

    constructor() {
        uint256[] memory boosterTvl = getBoosterTvl();
        uint256[] memory usgInfo = getUSGData();
        uint256[] memory tanInfo = getTanData();
        uint256[] memory combinedInfo = new uint256[](boosterTvl.length + usgInfo.length + tanInfo.length);
        for (uint256 i = 0; i < boosterTvl.length; i++) {
            combinedInfo[i] = boosterTvl[i];
        }
        for (uint256 i = 0; i < usgInfo.length; i++) {
            combinedInfo[i + boosterTvl.length] = usgInfo[i];
        }
        for (uint256 i = 0; i < tanInfo.length; i++) {
            combinedInfo[i + boosterTvl.length + usgInfo.length] = tanInfo[i];
        }
        revert LandingChainViewError(combinedInfo);
    }

    function getUSGData() internal returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](4);
        if (usg != address(0)) {
            USGInfoData memory usgInfo = getUSGInfo(usg, usgOracle, getKeepers(), sUSG);
            amounts[0] = usgInfo.circulatingUsg;
            amounts[1] = usgInfo.UsgPrice;
            amounts[2] = usgInfo.sUsgSupply;
            amounts[3] = usgInfo.usgStakedOnSgUsd;
        }
        return amounts;
    }

    function getTanData() internal returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](4);
        if (usg != address(0)) {
            RsTanInfoData memory tanInfo = getRsTanInfo(tan, tanPool, usg);
            amounts[0] = tanInfo.tanPrice;
            amounts[1] = tanInfo.totalSupplyVsTan;
            amounts[2] = tanInfo.rewardRate;
            amounts[3] = tanInfo.apr;
        }
        return amounts;
    }

    /*
     * @notice Get the total amount of token  of the booster (Stake DAO + Convex)
     * @return Array of token amounts of the booster
     */
    function getBoosterTvl() internal view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](6);

        // Get the stake DAO part
        address[] memory lpAssets = new address[](5);
        lpAssets[0] = sdCRVStaking;
        lpAssets[1] = sdPendleStaking;
        lpAssets[2] = sdFxnStaking;
        lpAssets[3] = sdBalStaking;
        lpAssets[4] = cvgSdtStaking;
        uint256 cvgSdtTotalStaked = 0;
        uint256 i = 0;
        for (i; i < lpAssets.length; i++) {
            IStakingPositionService sdtService = IStakingPositionService(lpAssets[i]);
            uint256 cycle = sdtService.stakingCycle();
            if (i == 4) {
                cvgSdtTotalStaked = sdtService.cycleInfo(cycle + 1).totalStaked;
            } else {
                amounts[i] = sdtService.cycleInfo(cycle + 1).totalStaked;
            }
        }
        // for cvgSDT check the peg and return the amount in SDT equivalent
        ICurvePool cvgSdtPoolContract = ICurvePool(cvgSdtPool);
        uint256 peggedSdtAmount = cvgSdtPoolContract.get_dy(1, 0, 1 ether);
        amounts[4] = (peggedSdtAmount * amounts[4]) / 1 ether; // SDT amount

        // Get the Convex part
        ICurvePool cvgSdtPoolContract = ICurvePool(cvgSdtPool);
        uint256 cvgSdtAmount = cvgSdtPoolContract.get_dy(1, 0, 1 ether);
        amounts[i - 1] = (cvgSdtAmount * cvgSdtTotalStaked) / 1 ether; // CVX amount

        // check the CVX1 amount ( pegged 1:1 to CVX )
        IStakingPositionService cvgCvxPositionService = IStakingPositionService(cvgCvxstaking);
        uint256 currentCycle = cvgCvxPositionService.stakingCycle();
        uint256 totalStaked = cvgCvxPositionService.cycleInfo(currentCycle + 1).totalStaked;
        ICurvePool cvgCvxCvx1PoolContract = ICurvePool(cvgCvxCvx1Pool);
        uint256 peggedCvxAmount = cvgCvxCvx1PoolContract.get_dy(1, 0, 1 ether);
        amounts[i] = (peggedCvxAmount * totalStaked) / 1 ether; // CVX amount

        return amounts;
    }
}
