// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenAmount} from "../../../interfaces/internals/ICommonStruct.sol";
import {ICvxBooster} from "../../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../../interfaces/externals/Convex/ICvxRewardToken.sol";

interface IConvexPoolUtilities {
    function rewardRates(uint256 _pid) external view returns (address[] memory tokens, uint256[] memory rates);
}

struct ConvexAPRData {
    uint256 pid;

    TokenAmount[] yearlyRewardPerLp;
}


contract ConvexAPR {
    uint256 private constant ONE_YEAR = 365 days;

    ICvxBooster private constant BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    IConvexPoolUtilities private constant POOL_UTILITIES = IConvexPoolUtilities(0x5Fba69a794F395184b5760DAf1134028608e5Cd1);

    error ConvexAPROut(ConvexAPRData[] output);

    constructor(uint256[] memory pids) {
        revert ConvexAPROut(getConvexAPRData(pids));
    }

    function getConvexAPRData(uint256[] memory pids) public view returns (ConvexAPRData[] memory) {
        ConvexAPRData[] memory output = new ConvexAPRData[](pids.length);
        for (uint256 i; i < pids.length; ) {
            uint256 pid = pids[i];
        
            (address[] memory tokens, uint256[] memory rates) = POOL_UTILITIES.rewardRates(pid);
            output[i] = ConvexAPRData({
                pid: pid,
                // rewardPool: rewardPool,
                // totalSupplyUnderlying: ICvxRewardToken(rewardPool).totalSupply(),
                yearlyRewardPerLp: _getYearlyRewardPerLp(tokens, rates)
            });

            unchecked {
                ++i;
            }
        }
        return output;
    }



    function _getYearlyRewardPerLp(address[] memory tokens, uint256[] memory rates) internal pure returns (TokenAmount[] memory) {
        uint256 len = tokens.length;
        TokenAmount[] memory temp = new TokenAmount[](len);
        uint256 count;

        for (uint256 i; i < len; ) {
            uint256 rate = rates[i];
            if (rate == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            bool found;

            for (uint256 j; j < count; ) {
                if (address(temp[j].token) == tokens[i]) {
                    temp[j].amount += rate * ONE_YEAR;
                    found = true;
                    break;
                }

                unchecked {
                    ++j;
                }
            }

            if (!found) {
                temp[count] = TokenAmount({token: IERC20(tokens[i]), amount: rate * ONE_YEAR});

                unchecked {
                    ++count;
                }
            }

            unchecked {
                ++i;
            }
        }

        TokenAmount[] memory yearlyRewardPerLp = new TokenAmount[](count);
        for (uint256 i; i < count; ) {
            yearlyRewardPerLp[i] = temp[i];

            unchecked {
                ++i;
            }
        }
        return yearlyRewardPerLp;
    }
}
