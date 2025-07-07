// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IVsTan} from "../../../interfaces/internals/USG/IVsTan.sol";
import {IVsTanERC721} from "../../../interfaces/internals/USG/IVsTanERC721.sol";

import {ERC20Infos, IERC20, TokenAmount} from "../../ERC20Infos.sol";

contract LockUI {
    error LockUIOutError(LockUIOut output);

    constructor(address user, IVsTan vsTan, IERC20 tan) {
        uint256 positionOwned = vsTan.balanceOf(user);

        LockUIOut memory output;
        output.totalSupply = tan.totalSupply();
        output.totalLocked = vsTan.totalSupplyVsTan();
        output.percentageLocked = output.totalSupply != 0 ? (output.totalLocked * 10 ** 6) / output.totalSupply : 0;
        output.tanAPR = 10 ** 19;

        if (user != address(0)) {
            positionOwned = vsTan.balanceOf(user);
            output.balance = tan.balanceOf(user);
            output.allowance = tan.allowance(user, address(vsTan));
        } else {
            positionOwned = 0;
        }
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
    LockedPosition[] positions;
}
