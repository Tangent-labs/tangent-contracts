// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {SdtPosition} from "../SdtPosition.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {AddrBooster} from "../../libs/resources/ResourcesBooster.sol";
import {AddrClassicERC20} from "../../libs/resources/ResourcesGlobal.sol";

contract CvgSdtDetail is SdtPosition, BalancesAllowances {
    struct OutputCvgCvxDetail {
        OutputBalanceAllowances[] obas;
        CvgCvxDetailOut detail;
    }

    struct CvgCvxDetailOut {
        uint256 totalStaked;
        uint256 userStaked;
        ICommonStruct.TokenAmount[] tokensClaimable;
        bool isProcessed;
    }

    error CvgCvxDetailError(OutputCvgCvxDetail output);

    constructor(address user) {
        revert CvgCvxDetailError(_getDetail(user));
    }

    function _getDetail(address user) public returns (OutputCvgCvxDetail memory) {
        if (user == address(0)) {
            return OutputCvgCvxDetail({obas: new OutputBalanceAllowances[](0), detail: _getDetailNotConnected()});
        } else {
            return OutputCvgCvxDetail({obas: _getBalAllow(user), detail: _getDetailConnected(user)});
        }
    }

    function _getDetailNotConnected() internal view returns (CvgCvxDetailOut memory) {
        uint256 nextCycle = AddrBooster.CVG_CVX_STAKING.stakingCycle() + 1;

        return
            CvgCvxDetailOut({
                totalStaked: AddrBooster.CVG_CVX_STAKING.cycleInfo(nextCycle).totalStaked,
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                isProcessed: AddrBooster.CVG_CVX_STAKING.cycleInfo(nextCycle - 2).isCvxProcessed
            });
    }

    function _getBalAllow(address user) internal view returns (OutputBalanceAllowances[] memory) {
        address cvgCvx1Lp = 0xc50E191F703FB3160fC15d8b168A8c740fec3666;

        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](2);

        address[] memory spenderCvx = new address[](3);
        spenderCvx[0] = address(AddrBooster.CVG_CVX_STAKING);
        spenderCvx[1] = address(AddrBooster.CVG_CVX);
        spenderCvx[2] = address(AddrBooster.CVX1);

        address[] memory spenderCvx1 = new address[](2);
        spenderCvx1[0] = address(AddrBooster.CVG_CVX_STAKING);
        spenderCvx1[1] = cvgCvx1Lp;

        address[] memory spenderCvgCVX = new address[](2);
        spenderCvgCVX[0] = address(AddrBooster.CVG_CVX_STAKING);
        spenderCvgCVX[1] = cvgCvx1Lp;

        ibas[0] = InputBalancesAllowances({token: AddrClassicERC20.TOKEN_CVX, spenders: spenderCvx});
        ibas[1] = InputBalancesAllowances({token: AddrBooster.CVG_CVX, spenders: spenderCvgCVX});
        ibas[2] = InputBalancesAllowances({token: AddrBooster.CVX1, spenders: spenderCvx1});

        return getBalancesAllowances(user, ibas);
    }

    function _getDetailConnected(address user) internal view returns (CvgCvxDetailOut memory) {
        uint256 nextCycle = AddrBooster.CVG_CVX_STAKING.stakingCycle() + 1;
        (, ICommonStruct.TokenAmount[] memory tokensClaimable) = AddrBooster.CVG_CVX_STAKING.getAllClaimableAmounts(user);

        return
            CvgCvxDetailOut({
                totalStaked: AddrBooster.CVG_CVX_STAKING.totalSupply(),
                userStaked: AddrBooster.CVG_CVX_STAKING.balanceOf(user),
                tokensClaimable: tokensClaimable,
                isProcessed: AddrBooster.CVG_CVX_STAKING.cycleInfo(nextCycle - 2).isCvxProcessed
            });
    }
}
