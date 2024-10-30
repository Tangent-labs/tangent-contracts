// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BalancesAllowances} from "../BalancesAllowances.sol";

import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ISdtStakingManager} from "../../interfaces/internals/CVG/ISdtStakingManager.sol";
import {ISdtUtilities} from "../../interfaces/internals/CVG/ISdtUtilities.sol";
import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoosterPosition {
    ISdtStakingManager public constant STAKING_MANAGER = ISdtStakingManager(0x7319662aD7D7ce2d1595073EA042B723F6d0dc48);
    ISdtUtilities public constant SDT_UTILITIES = ISdtUtilities(0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04);

    struct PositionData {
        uint256 tokenId;
        uint256 deposited;
        ICommonStruct.TokenAmount[] tokensClaimable;
    }

    function getAllOwnedPositions(address user) public view returns (ISdtStakingManager.TokenStaking[] memory) {
        return STAKING_MANAGER.getTokenIdsAndStakingContracts(user);
    }

    function getPositionsForOneStaking(
        ISdtStaking sdtStaking,
        ISdtStakingManager.TokenStaking[] memory allTokensOwned
    ) public view returns (PositionData[] memory) {
        PositionData[] memory positionsData = new PositionData[](allTokensOwned.length);
        uint256 counter;
        for (uint256 i; i < allTokensOwned.length; ) {
            uint256 tokenId = allTokensOwned[i].tokenId;
            if (allTokensOwned[i].stakingContract == sdtStaking) {
                (, ICommonStruct.TokenAmount[] memory tokensClaimable) = sdtStaking.getAllClaimableAmounts(tokenId);

                positionsData[counter] = PositionData({tokenId: tokenId, deposited: sdtStaking.tokenTotalStaked(tokenId), tokensClaimable: tokensClaimable});
                counter++;
            } else {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    /// @dev this reduce the length of the array to not return some useless 0 at the end
                    mstore(positionsData, sub(mload(positionsData), 1))
                }
            }
            unchecked {
                ++i;
            }
        }
        return positionsData;
    }

    struct MergedPositionData {
        uint256 deposited;
        ICommonStruct.TokenAmount[] tokensClaimable;
    }

    function getMergedPosition(
        ISdtStaking sdtStaking,
        ISdtStakingManager.TokenStaking[] memory allTokensOwned
    ) public returns (PositionData[] memory, MergedPositionData memory) {
        PositionData[] memory positions = getPositionsForOneStaking(sdtStaking, allTokensOwned);
        ICommonStruct.TokenAmount[] memory allTokensClaimable;
        if (positions.length == 0) {
            allTokensClaimable = new ICommonStruct.TokenAmount[](0);
        } else {
            allTokensClaimable = new ICommonStruct.TokenAmount[](5);
        }

        uint256 stakedByUser;
        uint256 realSizeClaimable;
        // We iterate through all the positions
        for (uint256 i; i < positions.length; ) {
            stakedByUser += positions[i].deposited;

            // We iterate through the claimable tokens
            for (uint256 j; j < positions[i].tokensClaimable.length; ) {
                ICommonStruct.TokenAmount memory tokenAmount = positions[i].tokensClaimable[j];
                IERC20 token = tokenAmount.token;
                uint256 amount = tokenAmount.amount;

                uint256 previousAmount = _tLoadUintForAddress(address(token));
                if (previousAmount == 0) {
                    allTokensClaimable[realSizeClaimable] = ICommonStruct.TokenAmount({token: token, amount: 0});
                    realSizeClaimable++;
                }

                _tStoreUintForAddress(address(token), previousAmount + amount);

                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (positions.length != 0) {
            realSizeClaimable = 5 - realSizeClaimable;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                /// @dev this reduce the length of the array to not return some useless 0 at the end
                mstore(allTokensClaimable, sub(mload(allTokensClaimable), realSizeClaimable))
            }

            for (uint256 i; i < allTokensClaimable.length; ) {
                IERC20 token = allTokensClaimable[i].token;
                allTokensClaimable[i].amount = _tLoadUintForAddress(address(token));
                _tStoreUintForAddress(address(token), 0);
                unchecked {
                    ++i;
                }
            }
        }

        return (positions, MergedPositionData({deposited: stakedByUser, tokensClaimable: allTokensClaimable}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _tStoreUintForAddress(address location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tLoadUintForAddress(address location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }
}
