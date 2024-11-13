// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SdtPosition} from "../SdtPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoosterList is SdtPosition {
    struct OutputBoosterList {
        BoosterRow crvRow;
        BoosterRow balRow;
        BoosterRow pendleRow;
        BoosterRow fxnRow;
    }

    struct BoosterRow {
        uint256 totalStaked;
        uint256 userStaked;
        ICommonStruct.TokenAmount[] tokensClaimable;
        bool isProcessed;
    }

    error BoosterListError(OutputBoosterList boosterList);

    constructor(address user) {
        revert BoosterListError(_getBoosterList(user));
    }

    function _getBoosterList(address user) public returns (OutputBoosterList memory) {
        if (user == address(0)) {
            return _getBoosterListNotConnected();
        } else {
            return _getBoosterListConnected(user);
        }
    }

    function _getBoosterListNotConnected() public view returns (OutputBoosterList memory) {
        return
            OutputBoosterList({
                crvRow: _getBoosterRowNotConnected(AddrBooster.SD_CRV_STAKING),
                balRow: _getBoosterRowNotConnected(AddrBooster.SD_BAL_STAKING),
                pendleRow: _getBoosterRowNotConnected(AddrBooster.SD_PENDLE_STAKING),
                fxnRow: _getBoosterRowNotConnected(AddrBooster.SD_FXN_STAKING)
            });
    }

    function _getBoosterRowNotConnected(ISdtStaking sdtStaking) public view returns (BoosterRow memory) {
        uint256 nextCycle = sdtStaking.stakingCycle() + 1;
        return
            BoosterRow({
                totalStaked: sdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                isProcessed: sdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getBoosterListConnected(address user) public returns (OutputBoosterList memory) {
        ISdtStakingManager.TokenStaking[] memory allPositions = getAllOwnedPositions(user);

        return
            OutputBoosterList({
                crvRow: _getBoosterRowConnected(AddrBooster.SD_CRV_STAKING, allPositions),
                balRow: _getBoosterRowConnected(AddrBooster.SD_BAL_STAKING, allPositions),
                pendleRow: _getBoosterRowConnected(AddrBooster.SD_PENDLE_STAKING, allPositions),
                fxnRow: _getBoosterRowConnected(AddrBooster.SD_FXN_STAKING, allPositions)
            });
    }

    function _getBoosterRowConnected(ISdtStaking sdtStaking, ISdtStakingManager.TokenStaking[] memory allPositions) public returns (BoosterRow memory) {
        uint256 nextCycle = sdtStaking.stakingCycle() + 1;

        (, MergedPositionData memory mergedPos) = getMergedPosition(sdtStaking, allPositions);

        return
            BoosterRow({
                totalStaked: sdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                isProcessed: sdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }
}
