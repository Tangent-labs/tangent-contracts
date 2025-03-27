// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRewards, TokenAmount} from "../../interfaces/internals/tgUSD/IRewards.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import "forge-std/console.sol";

contract RewardAccumulator is IRewardAccumulator, Ownable {
    using SafeERC20 for IERC20;

    IControlTower public controlTower;

    /// @notice Amount of fee that DAO can withdraw for a given token
    mapping(IERC20 => uint256) public cutFeeForToken;

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorrectRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();

    constructor(address _owner, IControlTower _controlTower) Ownable(_owner) {
        controlTower = _controlTower;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     *  @notice Claim rewards on one staking contract only
     *  @param market The erc20 to claim the rewards on
     */
    function claimSimple(address market) external {
        require(controlTower.isMarket(market), NotAMarketRewards());

        TokenAmount[] memory tokenAmounts = IRewards(market).getAndUpdateRewards(msg.sender);

        require(tokenAmounts.length != 0, NoRewardToSimpleClaim());

        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            tokenAmounts[erc20Id].token.safeTransfer(msg.sender, tokenAmounts[erc20Id].amount);
            unchecked {
                ++erc20Id;
            }
        }
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param markets Array of contract to claim the rewards on
     *  @param rewardLength Amount of different tokens to claim as a reward
     */
    function claimMultiple(address[] calldata markets, uint256 rewardLength) external {
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 marketsLen = markets.length;
        IERC20[] memory tokenList = new IERC20[](rewardLength);
        uint256 actualErc20Index;

        // Reverts if one of the market passed in parameter is not one
        controlTower.isContractsMarkets(markets);

        // Iterates through all of the vaults
        for (uint256 splitterTokenIndex; splitterTokenIndex < marketsLen; ) {
            address splitterToken = markets[splitterTokenIndex];
            // User input verification

            // Get and update the amount of rewards to claim
            TokenAmount[] memory tokenAmountsToClaim = IRewards(splitterToken).getAndUpdateRewards(msg.sender);
            // If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(splitterToken)));
            // Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 erc20 = tokenAmountsToClaim[tokenIndex].token;
                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 rewardAmount = _tLoadUintForAddress(address(erc20));

                if (rewardAmount == 0) {
                    // Increment tokenList length & add new token on new index
                    tokenList[actualErc20Index] = erc20;
                    unchecked {
                        ++actualErc20Index;
                    }
                }
                // Increment storage value
                _tStoreUintForAddress(address(erc20), rewardAmount + tokenAmountsToClaim[tokenIndex].amount);
                unchecked {
                    ++tokenIndex;
                }
            }

            unchecked {
                ++splitterTokenIndex;
            }
        }

        require(rewardLength == actualErc20Index, IncorrectRewardLength(rewardLength, actualErc20Index));

        // Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amountClaim);
                // Erase transient for the token
                _tStoreUintForAddress(address(token), 0);
            }

            unchecked {
                ++tokenIndex;
            }
        }
        require(isSomethingToClaim, NoRewardToMultiClaim());
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    FEES UPDATER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Increment dao fees that will be transferred in this contract during a process rewards.
     *         This function is only callable by an updater (scvUSD or gUSD).
     * @param tokens array of token to claim
     */
    function claimCutFees(IERC20[] memory tokens) external {
        address _feeTreasury = controlTower.feeTreasury();
        for (uint256 erc20Id; erc20Id < tokens.length; ) {
            IERC20 token = tokens[erc20Id];
            token.transfer(_feeTreasury, cutFeeForToken[token]);

            delete cutFeeForToken[token];
            unchecked {
                ++erc20Id;
            }
        }
    }
    /**
     * @notice Increment dao fees that will be transferred in this contract during a process rewards.
     *         This function is only callable by an updater (scvUSD or gUSD).
     * @param tokenAmounts Array of TokenAmount to used to increment fees
     */
    function incrementCutFees(TokenAmount[] memory tokenAmounts) external {
        require(controlTower.isMarket(msg.sender), NotAMarketRewards());
        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            cutFeeForToken[tokenAmounts[erc20Id].token] += tokenAmounts[erc20Id].amount;
            unchecked {
                ++erc20Id;
            }
        }
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
