// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {BoosterPosition} from "./BoosterPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/ResourcesBooster.sol";
import {AddrClassicERC20} from "../../libs/ResourcesGlobal.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoosterDetail is BoosterPosition, BalancesAllowances {
    struct OutputBoosterDetail {
        OutputBalanceAllowances[] obas;
        BoosterDetailOut boosterDetail;
    }

    struct BoosterDetailOut {
        uint256 totalStaked;
        uint256 userStaked;
        ICommonStruct.TokenAmount[] tokensClaimable;
        PositionData[] positionsDetails;
        bool isProcessed;
    }

    error BoosterDetailError(OutputBoosterDetail output);

    constructor(address user, ISdtStaking staking) {
        revert BoosterDetailError(_getBoosterDetail(user, staking));
    }

    function _getBoosterDetail(address user, ISdtStaking staking) public returns (OutputBoosterDetail memory) {
        if (user == address(0)) {
            return OutputBoosterDetail({obas: new OutputBalanceAllowances[](0), boosterDetail: _getBoosterDetailNotConnected(staking)});
        } else {
            return OutputBoosterDetail({obas: _getBoosterBalAllow(user, staking), boosterDetail: _getBoosterDetailConnected(user, staking)});
        }
    }

    function _getBoosterDetailNotConnected(ISdtStaking sdtStaking) internal view returns (BoosterDetailOut memory) {
        uint256 nextCycle = sdtStaking.stakingCycle() + 1;

        return
            BoosterDetailOut({
                totalStaked: sdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                positionsDetails: new PositionData[](0),
                isProcessed: sdtStaking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }

    function _getBoosterBalAllow(address user, ISdtStaking staking) internal view returns (OutputBalanceAllowances[] memory) {
        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](3);
        address[] memory spenderSdtUtilities = new address[](1);
        spenderSdtUtilities[0] = address(SDT_UTILITIES);

        address[] memory spenderStaking = new address[](1);

        // CRV
        if (staking == AddrBooster.SD_CRV_STAKING) {
            spenderStaking[0] = address(AddrBooster.SD_CRV_STAKING);
            ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_CRV, spenders: spenderSdtUtilities});
            ibas[1] = InputBalancesAllowances({token: AddrBooster.SD_CRV, spenders: spenderSdtUtilities});
            ibas[2] = InputBalancesAllowances({token: AddrBooster.SD_CRV_GAUGE, spenders: spenderStaking});
        } else if (staking == AddrBooster.SD_BAL_STAKING) {
            spenderStaking[0] = address(AddrBooster.SD_BAL_STAKING);
            ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_80_BAL_20_ETH, spenders: spenderSdtUtilities});
            ibas[1] = InputBalancesAllowances({token: AddrBooster.SD_BAL, spenders: spenderSdtUtilities});
            ibas[2] = InputBalancesAllowances({token: AddrBooster.SD_BAL_GAUGE, spenders: spenderStaking});
        } else if (staking == AddrBooster.SD_PENDLE_STAKING) {
            spenderStaking[0] = address(AddrBooster.SD_PENDLE_STAKING);
            ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_PENDLE, spenders: spenderSdtUtilities});
            ibas[1] = InputBalancesAllowances({token: AddrBooster.SD_PENDLE, spenders: spenderSdtUtilities});
            ibas[2] = InputBalancesAllowances({token: AddrBooster.SD_PENDLE_GAUGE, spenders: spenderStaking});
        } else {
            spenderStaking[0] = address(AddrBooster.SD_FXN_STAKING);
            ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_FXN, spenders: spenderSdtUtilities});
            ibas[1] = InputBalancesAllowances({token: AddrBooster.SD_FXN, spenders: spenderSdtUtilities});
            ibas[2] = InputBalancesAllowances({token: AddrBooster.SD_FXN_GAUGE, spenders: spenderStaking});
        }

        return getBalancesAllowances(user, ibas);
    }

    function _getBoosterDetailConnected(address user, ISdtStaking staking) internal returns (BoosterDetailOut memory) {
        ISdtStakingManager.TokenStaking[] memory allPositions = getAllOwnedPositions(user);
        uint256 nextCycle = staking.stakingCycle() + 1;

        (PositionData[] memory positionsDetails, MergedPositionData memory mergedPos) = getMergedPosition(staking, nextCycle, allPositions);

        return
            BoosterDetailOut({
                totalStaked: staking.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                positionsDetails: positionsDetails,
                isProcessed: staking.cycleInfo(nextCycle - 2).isSdtProcessed
            });
    }
}
