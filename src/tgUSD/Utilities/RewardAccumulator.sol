// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMarketRewards, ICommonStruct} from "../../interfaces/internals/tgUSD/IMarketRewards.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
contract RewardAccumulator is IRewardAccumulator, Ownable {
    using SafeERC20 for IERC20;

    address public feeTreasury;

    IControlTower public controlTower;

    /// @dev Gives the amount of fee that DAO can withdraw for an ERC20
    mapping(IERC20 => uint256) public cutFeeForToken;

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorretRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();

    constructor(address _owner, IControlTower _controlTower, address _feeTreasury) Ownable(_owner) {
        controlTower = _controlTower;
        feeTreasury = _feeTreasury;
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

        ICommonStruct.TokenAmount[] memory tokenAmounts = IMarketRewards(market).getAndUpdateRewards(msg.sender);

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
        uint256 lendTokensLength = markets.length;
        IERC20[] memory tokenList = new IERC20[](lendTokensLength);
        uint256 actualErc20Index;

        // Reverts if one of the market passed in parameter is not one
        controlTower.isContractsMarkets(markets);

        // Iterates through all of the vaults
        for (uint256 splitterTokenIndex; splitterTokenIndex < lendTokensLength; ) {
            address splitterToken = markets[splitterTokenIndex];
            // User input verification

            // Get and update the amount of rewards to claim
            ICommonStruct.TokenAmount[] memory tokenAmountsToClaim = IMarketRewards(splitterToken).getAndUpdateRewards(msg.sender);
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
            require(rewardLength == actualErc20Index, IncorretRewardLength(rewardLength, actualErc20Index));

            unchecked {
                ++splitterTokenIndex;
            }
        }

        // Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amountClaim);
                // Erase transient for the tokenP
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
        address _feeTreasury = feeTreasury;
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
    function incrementCutFees(ICommonStruct.TokenAmount[] memory tokenAmounts) external {
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
