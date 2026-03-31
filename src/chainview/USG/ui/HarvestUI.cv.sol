// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRewardAccumulator, Reward} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../../interfaces/internals/USG/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket, IStakingProxyERC20} from "../../../interfaces/internals/USG/IConvexFxnLPMarket.sol";
import {IStakeDaoVaultV2Market, IStakeDaoVaultV2} from "../../../interfaces/internals/USG/IStakeDaoVaultV2Market.sol";
import {IGauge} from "../../../interfaces/externals/Curve/IGauge.sol";
import {IAccountant} from "../../../interfaces/externals/StakeDao/IAccountant.sol";
import {ERC20Infos, IERC20, TokenAmount, ERC20Infos, ERC20AmountInfos} from "../../ERC20Infos.sol";
import "../../../../src/interfaces/externals/Convex/IStashTokenWrapper.sol";

struct HarvestUIIn {
    address marketAddress;
    uint256 marketType;
}

interface ICVX is IERC20 {
    function totalCliffs() external view returns (uint256);
    function reductionPerCliff() external view returns (uint256);
    function maxSupply() external view returns (uint256);
}

struct HarvestUIOut {
    address marketAddress;
    string collateralName;
    uint256 harvesterFeePercentage;
    uint256 lastHarvestDate;
    ERC20AmountInfos[] balancesRewards;
    TokenAmount[] claimableRewards;
}

contract HarvestUI is ERC20Infos {
    error HarvestUIOutError(HarvestUIOut[] output);

    constructor(HarvestUIIn[] memory markets, IRewardAccumulator rewardAccumulator) {
        uint256 marketLength = markets.length;
        HarvestUIOut[] memory output = new HarvestUIOut[](marketLength);

        for (uint256 i; i < marketLength; ) {
            address market = markets[i].marketAddress;
            uint256 marketType = markets[i].marketType;
            IERC20[] memory erc20s = rewardAccumulator.getRewardTokens(market);
            uint256 erc20sLength = erc20s.length;
            uint256 lastPeriodFinish;
            TokenAmount[] memory claimableRewards;
            // Convex CRV
            if (marketType == 0) {
                claimableRewards = _getClaimableConvexCrv(market, IConvexCrvLPMarket(market).cvxRewardToken());
            }
            // Convex FXN
            else if (marketType == 1) {
                claimableRewards = _getClaimableConvexFXN(IConvexFxnLPMarket(market).stakingProxyVault());
            }
            // Stake DAO
            else if (marketType == 2) {
                claimableRewards = _getStakeDaoCRV(market, IStakeDaoVaultV2(MarketReceipt(market).receiptToken()).gauge(), erc20s);
            }
            // Curve gauge
            else if (marketType == 3) {
                claimableRewards = _getClaimableCurveGauge(market, IGauge(MarketReceipt(market).receiptToken()));
            }

            // Reward token held by the market
            ERC20AmountInfos[] memory balancesRewards = new ERC20AmountInfos[](erc20sLength);
            for (uint256 j; j < erc20s.length; ) {
                IERC20 rewardToken = erc20s[j];
                Reward memory rewardData = rewardAccumulator.getRewardData(market, rewardToken);
                lastPeriodFinish = lastPeriodFinish < rewardData.periodFinish ? rewardData.periodFinish : lastPeriodFinish;
                balancesRewards[j] = getERC20AmountInfos(TokenAmount({token: rewardToken, amount: rewardToken.balanceOf(market)}));

                unchecked {
                    ++j;
                }
            }

            output[i] = HarvestUIOut({
                marketAddress: market,
                collateralName: ICollateral(market).collatToken().symbol(),
                harvesterFeePercentage: rewardAccumulator.getRCParams(market).harvestFeePercentage,
                lastHarvestDate: lastPeriodFinish == 0 ? 0 : lastPeriodFinish - 7 days,
                balancesRewards: balancesRewards,
                claimableRewards: claimableRewards
            });
            unchecked {
                ++i;
            }
        }
        revert HarvestUIOutError(output);
    }

    function _getCvxAmountMinted(uint256 crvAmount) internal view returns (uint256) {
        uint256 cvxToMint;
        uint256 cliff = CVX.totalSupply() / CVX.reductionPerCliff();
        uint256 totalCliffs = CVX.totalCliffs();
        if (cliff < totalCliffs) {
            //for reduction% take inverse of current cliff
            uint256 reduction = totalCliffs - cliff;
            //reduce
            cvxToMint = (crvAmount * reduction) / totalCliffs;

            //supply cap check
            uint256 amtTillMax = CVX.maxSupply() - CVX.totalSupply();
            if (cvxToMint > amtTillMax) {
                cvxToMint = amtTillMax;
            }
        }

        return cvxToMint;
    }

    address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    ICVX constant CVX = ICVX(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    function _getClaimableConvexCrv(address account, ICvxRewardToken cvxRewardToken) internal view returns (TokenAmount[] memory) {
        // Retrieve CRV amount claimable
        uint256 crvAmount = cvxRewardToken.earned(account);

        // Deduce cvxAmount bcs it's proportionnal
        uint256 cvxAmount = _getCvxAmountMinted(crvAmount);

        // Retrieve extra rewards claimable, first part
        uint256 extraRewardsAmount = cvxRewardToken.extraRewardsLength();

        TokenAmount[] memory claimable = new TokenAmount[](extraRewardsAmount + 1);
        claimable[0] = TokenAmount({token: IERC20(CRV), amount: crvAmount});
        claimable[1] = TokenAmount({token: IERC20(CVX), amount: cvxAmount});

        for (uint256 i; i < extraRewardsAmount; i++) {
            ICvxRewardToken xtraRewardToken = ICvxRewardToken(cvxRewardToken.extraRewards(i));
            IStashTokenWrapper wrapper = IStashTokenWrapper(xtraRewardToken.rewardToken());
            IERC20Metadata realRewardToken = wrapper.token();
            // The first extra reward is always CVX
            if (i == 0) {
                claimable[1].amount += xtraRewardToken.earned(account);
            } else {
                claimable[i + 1] = TokenAmount({token: realRewardToken, amount: xtraRewardToken.earned(account)});
            }
        }

        return claimable;
    }

    function _getClaimableConvexFXN(IStakingProxyERC20 stakingProxyVault) internal returns (TokenAmount[] memory) {
        // Retrieve CRV amount claimable
        (address[] memory tokens, uint256[] memory amounts) = stakingProxyVault.earned();
        uint256 len = tokens.length;
        TokenAmount[] memory claimable = new TokenAmount[](len);

        for (uint256 i; i < len; i++) {
            claimable[i] = TokenAmount({token: IERC20(tokens[i]), amount: amounts[i]});
        }
        return claimable;
    }

    function _getClaimableCurveGauge(address account, IGauge gauge) internal view returns (TokenAmount[] memory) {
        uint256 rewardAmount = gauge.reward_count();
        TokenAmount[] memory claimable = new TokenAmount[](rewardAmount);

        for (uint256 i; i < rewardAmount; i++) {
            address token = gauge.reward_tokens(i);
            claimable[i] = TokenAmount({token: IERC20(token), amount: gauge.claimable_reward(account, token)});
        }

        return claimable;
    }

    IAccountant constant accountant = IAccountant(0x93b4B9bd266fFA8AF68e39EDFa8cFe2A62011Ce0);
    IProtocolController constant protocolController = IProtocolController(0x2d8BcE1FaE00a959354aCD9eBf9174337A64d4fb);
    ICampaignRewardsDistributor constant campaignRewardsDistributor = ICampaignRewardsDistributor(0xD4898A378eA555595c4E7dbDE722B134a3F346D1);
    uint128 constant SCALING_FACTOR = 1e27;

    function _getStakeDaoCRV(address account, address gauge, IERC20[] memory extraRewards) internal view returns (TokenAmount[] memory) {
        uint256 claimableCRV;
        address vault = protocolController.vault(gauge);
        uint256 extraRewardsLen = extraRewards.length;
        TokenAmount[] memory claimable = new TokenAmount[](1 + extraRewardsLen);

        // Get the account data for this gauge
        (uint128 balance, uint256 accountIntegral, uint256 pendingRewards) = accountant.accounts(vault, account);

        // If account has any rewards to claim for this vault, calculate the amount. Otherwise, skip.
        if (balance != 0 || pendingRewards != 0) {
            (uint256 vaultIntegral, , , , , , ) = accountant.vaults(vault);

            // If vault's integral is higher than account's integral, calculate the rewards and update the total.
            uint256 claimableAmount = pendingRewards;
            if (vaultIntegral > accountIntegral) {
                claimableAmount += ((vaultIntegral - accountIntegral) * balance) / SCALING_FACTOR;
            }

            // In any case, add the pending rewards to the total amount
            claimableCRV += claimableAmount;
        }

        claimable[0] = TokenAmount({token: IERC20(CRV), amount: claimableCRV});
        address _account = account;
        // Already claimed extra rewards
        for (uint256 i; i < extraRewardsLen; i++) {
            IERC20 token = extraRewards[i];
            claimable[i + 1] = TokenAmount({token: token, amount: campaignRewardsDistributor.claimed(_account, address(token))});
        }

        return claimable;
    }
}
interface IProtocolController {
    function vault(address gauge) external view returns (address);
}

interface ICampaignRewardsDistributor {
    function claimed(address account, address token) external view returns (uint256);
}

interface MarketReceipt {
    function receiptToken() external view returns (address);
}
