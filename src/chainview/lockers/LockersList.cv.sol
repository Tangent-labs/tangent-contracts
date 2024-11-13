// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SdtPosition} from "../SdtPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ICvxStaking} from "../../interfaces/internals/CVG/ICvxStaking.sol";

import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoosterList is SdtPosition {
    struct OutputLockerList {
        LockerRow cvgSdt;
        LockerRow cvgCvx;
    }

    struct LockerRow {
        uint256 totalStaked;
        uint256 userStaked;
        ICommonStruct.TokenAmount[] tokensClaimable;
        bool isProcessed;
    }

    error LockerListError(OutputLockerList lockerList);

    constructor(address user) {
        revert LockerListError(_getLockerList(user));
    }

    function _getLockerList(address user) public returns (OutputLockerList memory) {
        if (user == address(0)) {
            return OutputLockerList({cvgSdt: _getCvgSdtRowNotConnected(), cvgCvx: _getCvgSdtRowNotConnected()});
        } else {
            return OutputLockerList({cvgSdt: _getCvgSdtRowConnected(user), cvgCvx: _getCvgSdtRowConnected(user)});
        }
    }

    function _getCvgSdtRowNotConnected() public view returns (LockerRow memory) {
        ISdtStaking cvgSdtStaking = AddrBooster.CVG_SDT_STAKING;
        uint256 nextCycle = cvgSdtStaking.stakingCycle() + 1;
        return
            LockerRow({
                totalStaked: cvgSdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                isProcessed: cvgSdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getCvgSdtRowConnected(address user) public returns (LockerRow memory) {
        ISdtStaking cvgSdtStaking = AddrBooster.CVG_SDT_STAKING;
        uint256 nextCycle = cvgSdtStaking.stakingCycle() + 1;

        (, MergedPositionData memory mergedPos) = getMergedPosition(cvgSdtStaking, getAllOwnedPositions(user));

        return
            LockerRow({
                totalStaked: cvgSdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                isProcessed: cvgSdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getCvgCvxRowNotConnected() public view returns (LockerRow memory) {
        ICvxStaking cvgCvxStaking = AddrBooster.CVG_CVX_STAKING;
        uint256 nextCycle = cvgCvxStaking.stakingCycle() + 1;
        return
            LockerRow({
                totalStaked: cvgCvxStaking.totalSupply(),
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                isProcessed: cvgCvxStaking.cycleInfo(nextCycle - 2).isCvxProcessed
            });
    }

    function _getCvgCvxRowConnected(address user) public view returns (LockerRow memory) {
        ICvxStaking cvgCvxStaking = AddrBooster.CVG_CVX_STAKING;
        uint256 nextCycle = cvgCvxStaking.stakingCycle() + 1;

        (, ICommonStruct.TokenAmount[] memory tokensClaimable) = cvgCvxStaking.getAllClaimableAmounts(user);

        return
            LockerRow({
                totalStaked: cvgCvxStaking.totalSupply(),
                userStaked: cvgCvxStaking.balanceOf(user),
                tokensClaimable: tokensClaimable,
                isProcessed: cvgCvxStaking.cycleInfo(nextCycle - 2).isCvxProcessed
            });
    }
}
