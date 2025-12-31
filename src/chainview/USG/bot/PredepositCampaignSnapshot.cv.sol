// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PredepositCampaignSnapshot {
    error PredepositCampaignSnapshotError(uint256[][] balances);
    // Arrays usgUSDC & usgFrxUSD should be
    constructor(address[] memory users, IERC20[] memory usgUsdc, IERC20[] memory usgFrxusd) {
        uint256[][] memory out = new uint256[][](2);

        out[0] = _getBalancesForUser(users, usgUsdc);
        out[1] = _getBalancesForUser(users, usgFrxusd);

        revert PredepositCampaignSnapshotError(out);
    }

    function _getBalancesForUser(address[] memory users, IERC20[] memory tokens) internal view returns (uint256[] memory) {
        uint256 usrLen = users.length;
        uint256 tokenLen = tokens.length;

        uint256[] memory balances = new uint256[](usrLen);

        for (uint256 i; i < usrLen; ) {
            address usr = users[i];
            uint256 bal;
            for (uint256 j; j < tokenLen; ) {
                bal += tokens[j].balanceOf(usr);
                unchecked {
                    ++j;
                }
            }
            balances[i] = bal;
            unchecked {
                ++i;
            }
        }
        return balances;
    }
}
