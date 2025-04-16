// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SdtPosition} from "../SdtPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

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
        TokenAmount[] tokensClaimable;
        PositionData[] positionsDetails;
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
        console.log("yoyo");
        uint256 nextCycle = sdtStaking.stakingCycle() + 1;
        return
            BoosterRow({
                totalStaked: sdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new TokenAmount[](0),
                positionsDetails: new PositionData[](0),
                isProcessed: sdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getBoosterListConnected(address user) public returns (OutputBoosterList memory) {
        return
            OutputBoosterList({
                crvRow: _getBoosterRowConnected(user, AddrBooster.SD_CRV_STAKING),
                balRow: _getBoosterRowConnected(user, AddrBooster.SD_BAL_STAKING),
                pendleRow: _getBoosterRowConnected(user, AddrBooster.SD_PENDLE_STAKING),
                fxnRow: _getBoosterRowConnected(user, AddrBooster.SD_FXN_STAKING)
            });
    }

    function _getBoosterRowConnected(address user, ISdtStaking staking) internal returns (BoosterRow memory) {
        console.log("yoyo");
        ISdtStakingManager.TokenStaking[] memory allPositions = getAllOwnedPositions(user);
        console.log("aurevoir");
        uint256 nextCycle = staking.stakingCycle() + 1;

        (PositionData[] memory positionsDetails, MergedPositionData memory mergedPos) = getMergedPosition(staking, allPositions);

        return
            BoosterRow({
                totalStaked: staking.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                positionsDetails: positionsDetails,
                isProcessed: staking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }
}
