// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct TokenBalance {
    address token;
    uint256 balance;
}

struct BoostBalancesSnapshotsOut {
    address user;
    TokenBalance[] tokenBalance;
}

interface IVlCVX {
    function lockedBalanceOf(address balance) external view returns (uint256);
}
contract BoostBalancesSnapshots {
    error BoostBalancesSnapshotsError(uint256 timestamp, BoostBalancesSnapshotsOut[] out);

    constructor(IERC20[] memory tokens, address[] memory users) {
        revert BoostBalancesSnapshotsError(block.timestamp, _getOut(tokens, users));
    }

    function _getOut(IERC20[] memory tokens, address[] memory users) internal view returns (BoostBalancesSnapshotsOut[] memory) {
        uint256 tokenLen = tokens.length;
        uint256 usrLen = users.length;

        BoostBalancesSnapshotsOut[] memory out = new BoostBalancesSnapshotsOut[](usrLen);

        for (uint256 i = 0; i < usrLen; i++) {
            address usr = users[i];
            TokenBalance[] memory tokenBalances = new TokenBalance[](tokenLen + 1);
            uint256 count = 0;

            // Part for tokens respectiong ERC20 interface ( balanceOf )
            for (uint256 j = 0; j < tokenLen; j++) {
                IERC20 token = tokens[j];
                uint256 _bal = token.balanceOf(usr);

                if (_bal > 0) {
                    tokenBalances[count] = TokenBalance({token: address(token), balance: _bal});
                    count++;
                }
            }

            // For vlCVX, we are calling vlCVX
            IVlCVX vlCVX = IVlCVX(0x72a19342e8F1838460eBFCCEf09F6585e32db86E);
            uint256 bal = vlCVX.lockedBalanceOf(usr);

            if (bal > 0) {
                tokenBalances[count] = TokenBalance({token: address(vlCVX), balance: bal});
                count++;
            }

            assembly {
                mstore(tokenBalances, count)
            }

            out[i] = BoostBalancesSnapshotsOut({user: usr, tokenBalance: tokenBalances});
        }

        return out;
    }
}
