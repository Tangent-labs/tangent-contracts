// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20Infos, IERC20, TokenAmount} from "../../ERC20Infos.sol";

import {VsTANInfo, IVsTan, ICurveCryptoSwap, IAggregatorV3, IAggregatorStablePriceV3} from "../../VsTANInfo.sol";

contract LockUI is VsTANInfo {
    error LockUIOutError(LockUIOut output);

    constructor(address user, IERC20 tan, IVsTan vsTan, ICurveCryptoSwap tanLP, IERC20 usg, IAggregatorV3 ethOracle, IAggregatorStablePriceV3 usgOracle, address dao) {
        uint256 positionOwned = user == address(0) ? 0 : vsTan.balanceOf(user);

        RsTanData memory rsTanGlobalData = getVsTanInfo(vsTan, tanLP, usg, ethOracle, usgOracle);

        LockUIOut memory output;
        output.totalSupply = tan.totalSupply();
        output.totalLocked = rsTanGlobalData.totalSupplyVsTan;
        output.percentageLocked = output.totalSupply != 0 ? (output.totalLocked * 1e18) / (output.totalSupply - tan.balanceOf(dao)) : 0;
        output.tanPrice = rsTanGlobalData.tanPrice;
        output.tanAPR = rsTanGlobalData.apr;

        output.balance = user == address(0) ? 0 : tan.balanceOf(user);
        output.allowance = user == address(0) ? 0 : tan.allowance(user, address(vsTan));
    
        LockedPosition[] memory positions = new LockedPosition[](positionOwned);

        for (uint256 i; i < positionOwned; ) {
            uint256 tokenId = vsTan.tokenOfOwnerByIndex(user, i);
            (uint48 endLockTime, uint208 amount) = vsTan.locks(tokenId);

            positions[i] = LockedPosition({tokenId: tokenId, endLockTime: endLockTime, amount: amount, claimable: vsTan.claimableRewards(tokenId)[0].amount});
            unchecked {
                ++i;
            }
        }
        output.positions = positions;

        revert LockUIOutError(output);
    }
}
struct LockedPosition {
    uint256 tokenId;
    uint48 endLockTime;
    uint208 amount;
    uint256 claimable;
}

struct LockUIOut {
    uint256 balance;
    uint256 allowance;
    uint256 totalSupply;
    uint256 totalLocked;
    uint256 percentageLocked;
    uint256 tanAPR;
    uint256 tanPrice;
    LockedPosition[] positions;
}
