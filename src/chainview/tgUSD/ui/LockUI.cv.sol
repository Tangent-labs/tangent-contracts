// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {IRsTan} from "../../../interfaces/internals/tgUSD/IRsTan.sol";

import {ERC20Infos, IERC20, TokenAmount} from "../../ERC20Infos.sol";

contract LockUI {
    error LockUIOutError(LockUIOut output);

    constructor(address user, IRsTan rsTan, IERC20 tan) {
        uint256 positionOwned = rsTan.balanceOf(user);

        LockUIOut memory output;
        output.totalSupply = tan.totalSupply();
        output.totalLocked = rsTan.totalSupplyRsTan();
        output.percentageLocked = output.totalSupply != 0 ? (output.totalLocked * 10 ** 6) / output.totalSupply : 0;
        output.tanAPR = 10 ** 19;

        if (user != address(0)) {
            positionOwned = rsTan.balanceOf(user);
            output.balance = tan.balanceOf(user);
            output.allowance = tan.allowance(user, address(rsTan));
        } else {
            positionOwned = 0;
        }
        LockedPosition[] memory positions = new LockedPosition[](positionOwned);

        for (uint256 i; i < positionOwned; ) {
            uint256 tokenId = rsTan.tokenOfOwnerByIndex(user, i);
            (uint48 endLockTime, uint208 amount) = rsTan.locks(tokenId);

            positions[i] = LockedPosition({tokenId: tokenId, endLockTime: endLockTime, amount: amount, claimable: rsTan.claimableRewards(tokenId)});
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
    TokenAmount[] claimable;
}

struct LockUIOut {
    uint256 balance;
    uint256 allowance;
    uint256 totalSupply;
    uint256 totalLocked;
    uint256 percentageLocked;
    uint256 tanAPR;
    LockedPosition[] positions;
}
