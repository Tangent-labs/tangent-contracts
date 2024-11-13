// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMarketRewards, ICommonStruct} from "../../interfaces/internals/tgUSD/IMarketRewards.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";

contract RewardAccumulator is IRewardAccumulator, Ownable {
    using SafeERC20 for IERC20;

    address public feeTreasury;

    /// @dev Gives the amount of fee that DAO can withdraw for an ERC20
    mapping(IERC20 => uint256) public cutFeeForToken;
    /// @dev Determines if address is scvUSD or gUSD
    mapping(address => bool) public isMarketRewards;

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorretRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();

    constructor(address _owner, address _feeTreasury) Ownable(_owner) {
        feeTreasury = _feeTreasury;
    }

    function toggleMarketRewards(address[] calldata _marketRewards) external onlyOwner {
        for (uint256 i; i < _marketRewards.length; ) {
            address _marketReward = _marketRewards[i];

            isMarketRewards[_marketReward] = !isMarketRewards[_marketReward];

            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /**
     *  @notice Claim rewards on one staking contract only
     *  @param market The erc20 to claim the rewards on
     */
    function claimSimple(address market) external {
        require(isMarketRewards[market], NotAMarketRewards());

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
     *  @param splitterTokens Array of contract to claim the rewards on
     *  @param rewardLength Amount of different tokens to claim as a reward
     */
    function claimMultiple(address[] calldata splitterTokens, uint256 rewardLength) external {
        /// @dev We save this length on his own variable, to not miss with the assembly manipulations
        uint256 lendTokensLength = splitterTokens.length;
        IERC20[] memory tokenList = new IERC20[](lendTokensLength);
        uint256 actualErc20Index;

        /// @dev Iterates through all of the vaults
        for (uint256 splitterTokenIndex; splitterTokenIndex < lendTokensLength; ) {
            address splitterToken = splitterTokens[splitterTokenIndex];
            /// @dev User input verification
            require(isMarketRewards[splitterToken], NotAMarketRewards());

            /// @dev Get and update the amount of rewards to claim
            ICommonStruct.TokenAmount[] memory tokenAmountsToClaim = IMarketRewards(splitterToken).getAndUpdateRewards(msg.sender);
            /// @dev If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(splitterToken)));

            /// @dev Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 erc20 = tokenAmountsToClaim[tokenIndex].token;
                /// @dev If token is seen the first time (tokensToClaim[token] == 0)
                uint256 rewardAmount = _tLoadUintForAddress(address(erc20));
                if (rewardAmount == 0) {
                    /// @dev Increment tokenList length & add new token on new index
                    tokenList[actualErc20Index] = erc20;
                    unchecked {
                        ++actualErc20Index;
                    }
                }
                /// @dev Increment storage value
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

        /// @dev Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amountClaim);
                /// @dev Erase transient for the token
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
     * @param tokenAmounts array of token to used to increment fees
     */
    function incrementCutFees(ICommonStruct.TokenAmount[] memory tokenAmounts) external {
        require(isMarketRewards[msg.sender], NotAMarketRewards());
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
