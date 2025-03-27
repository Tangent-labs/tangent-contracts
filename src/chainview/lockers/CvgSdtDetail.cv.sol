// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {SdtPosition} from "../SdtPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";
import {AddrClassicERC20} from "../../libs/Resources/ResourcesGlobal.sol";

contract CvgSdtDetail is SdtPosition, BalancesAllowances {
    struct OutputCvgSdtDetail {
        OutputBalanceAllowances[] obas;
        CvgSdtDetailOut detail;
    }

    struct CvgSdtDetailOut {
        uint256 totalStaked;
        uint256 userStaked;
        TokenAmount[] tokensClaimable;
        PositionData[] positionsDetails;
        bool isProcessed;
    }

    error CvgSdtDetailError(OutputCvgSdtDetail output);

    constructor(address user) {
        revert CvgSdtDetailError(_getDetail(user));
    }

    function _getDetail(address user) public returns (OutputCvgSdtDetail memory) {
        if (user == address(0)) {
            return OutputCvgSdtDetail({obas: new OutputBalanceAllowances[](0), detail: _getDetailNotConnected()});
        } else {
            return OutputCvgSdtDetail({obas: _getBalAllow(user), detail: _getDetailConnected(user)});
        }
    }

    function _getDetailNotConnected() internal view returns (CvgSdtDetailOut memory) {
        uint256 nextCycle = AddrBooster.CVG_SDT_STAKING.stakingCycle() + 1;

        return
            CvgSdtDetailOut({
                totalStaked: AddrBooster.CVG_SDT_STAKING.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new TokenAmount[](0),
                positionsDetails: new PositionData[](0),
                isProcessed: AddrBooster.CVG_SDT_STAKING.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getBalAllow(address user) internal view returns (OutputBalanceAllowances[] memory) {
        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](2);

        address[] memory spenderSdt = new address[](2);
        spenderSdt[0] = address(SDT_UTILITIES);
        spenderSdt[1] = address(AddrBooster.CVG_SDT);

        address[] memory spenderStaking = new address[](1);
        spenderStaking[0] = address(AddrBooster.CVG_SDT_STAKING);

        ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_SDT, spenders: spenderSdt});
        ibas[1] = InputBalancesAllowances({token: AddrBooster.CVG_SDT, spenders: spenderStaking});

        return getBalancesAllowances(user, ibas);
    }

    function _getDetailConnected(address user) internal returns (CvgSdtDetailOut memory) {
        uint256 nextCycle = AddrBooster.CVG_SDT_STAKING.stakingCycle() + 1;

        (PositionData[] memory positionsDetails, MergedPositionData memory mergedPos) = getMergedPosition(AddrBooster.CVG_SDT_STAKING, getAllOwnedPositions(user));

        return
            CvgSdtDetailOut({
                totalStaked: AddrBooster.CVG_SDT_STAKING.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                positionsDetails: positionsDetails,
                isProcessed: AddrBooster.CVG_SDT_STAKING.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }
}
