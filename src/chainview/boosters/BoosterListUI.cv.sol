// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {BoosterPosition} from "./BoosterPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/oldCvg/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/oldCvg/ISdtStakingManager.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/ResourcesBooster.sol";
import {AddrClassicERC20} from "../../libs/ResourcesGlobal.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoosterListUI is BoosterPosition, BalancesAllowances {
    address constant SDT_UTILITIES = 0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04;

    struct OutputBoosterList {
        OutputBalanceAllowances[] obas;
        BoosterList boosterList;
    }

    struct BoosterList {
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

    error BoosterListError(OutputBoosterList output);

    constructor(address user, InputBalancesAllowances[] memory ibas) {
        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](12);
        address[] memory spenderSdtUtilities = new address[](1);
        spenderSdtUtilities[0] = SDT_UTILITIES;

        address[] memory spenderStaking = new address[](1);

        // CRV

        spenderStaking[0] = address(AddrBooster.SD_CRV_STAKING);
        ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_CRV, spenders: spenderSdtUtilities});
        ibas[1] = InputBalancesAllowances({token: AddrBooster.SD_CRV, spenders: spenderSdtUtilities});
        ibas[2] = InputBalancesAllowances({token: AddrBooster.SD_CRV_GAUGE, spenders: spenderStaking});

        // BAL

        spenderStaking[0] = address(AddrBooster.SD_BAL_STAKING);
        ibas[3] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_BAL, spenders: spenderSdtUtilities});
        ibas[4] = InputBalancesAllowances({token: AddrBooster.SD_BAL, spenders: spenderSdtUtilities});
        ibas[5] = InputBalancesAllowances({token: AddrBooster.SD_BAL_GAUGE, spenders: spenderStaking});

        // PENDLE

        spenderStaking[0] = address(AddrBooster.SD_PENDLE_STAKING);
        ibas[6] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_PENDLE, spenders: spenderSdtUtilities});
        ibas[7] = InputBalancesAllowances({token: AddrBooster.SD_PENDLE, spenders: spenderSdtUtilities});
        ibas[8] = InputBalancesAllowances({token: AddrBooster.SD_PENDLE_GAUGE, spenders: spenderStaking});

        // FXN

        spenderStaking[0] = address(AddrBooster.SD_FXN_STAKING);
        ibas[9] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_FXN, spenders: spenderSdtUtilities});
        ibas[10] = InputBalancesAllowances({token: AddrBooster.SD_FXN, spenders: spenderSdtUtilities});
        ibas[11] = InputBalancesAllowances({token: AddrBooster.SD_FXN_GAUGE, spenders: spenderStaking});

        revert BoosterListError(OutputBoosterList({obas: getBalancesAllowances(user, ibas), boosterList: getBoosterList(user)}));
    }

    function getBoosterList(address user) public returns (BoosterList memory) {
        ISdtStakingManager.TokenStaking[] memory allPositions = getAllOwnedPositions(user);

        return
            BoosterList({
                crvRow: getBoosterRow(AddrBooster.SD_CRV_STAKING, allPositions),
                balRow: getBoosterRow(AddrBooster.SD_BAL_STAKING, allPositions),
                pendleRow: getBoosterRow(AddrBooster.SD_PENDLE_STAKING, allPositions),
                fxnRow: getBoosterRow(AddrBooster.SD_FXN_STAKING, allPositions)
            });
    }

    function getBoosterRow(ISdtStaking sdtStaking, ISdtStakingManager.TokenStaking[] memory allPositions) public returns (BoosterRow memory) {
        uint256 nextCycle = sdtStaking.stakingCycle() + 1;

        (, MergedPositionData memory mergedPos) = getMergedPosition(sdtStaking, nextCycle, allPositions);

        return
            BoosterRow({
                totalStaked: sdtStaking.cycleInfo(nextCycle).totalStaked,
                userStaked: mergedPos.deposited,
                tokensClaimable: mergedPos.tokensClaimable,
                isProcessed: false
            });
    }
}
