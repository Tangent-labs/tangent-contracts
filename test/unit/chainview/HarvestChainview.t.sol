// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/USG/ui/HarvestUI.cv.sol";

import "../../../src/interfaces/externals/Convex/IStashTokenWrapper.sol";

contract HarvestChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;
    ConvexFxnLPMarket public market3;
    BasicERC20Market public market4;

    function setUp() public {
        // market1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        // market2 = deployConvexCurveLPMarket(AddrCurveStableLP.WETH_pxETH);
        // market3 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        // market4 = deployBasicERC20Market(AddrPTPendle.eUSDe_29_05_25);
        vm.createSelectFork("mainnet", 24749020);
    }

    // // LIST
    // function test_harvest_ui_returns() public {
    //     HarvestUIIn[] memory markets = new HarvestUIIn[](4);
    //     markets[0] = HarvestUIIn({marketAddress: market1, marketType: 0});
    //     markets[1] = HarvestUIIn({marketAddress: market2, marketType: 0});
    //     markets[2] = HarvestUIIn({marketAddress: market3, marketType: 1});
    //     markets[3] = HarvestUIIn({marketAddress: market4, marketType: 0});
    //     try new HarvestUI(markets, rewardAccumulator) {} catch (bytes memory reason) {
    //         assertTrue(reason.length > 3, "Chainview failed");
    //     }
    // }

    // LIST
    // function test_Convex_CRV_complex() public {
    //     _getClaimableConvexCrv(0xEb2A77971d5A8d3b458b81e7964DE27a2453F84a, ICvxRewardToken(0xC75C8C6d2D47AAa711d79E1FE20D4cb1AD147702));
    // }

    // address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    // address constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    // function _getClaimableConvexCrv(address account, ICvxRewardToken cvxRewardToken) internal returns (TokenAmount[] memory) {
    //     // Retrieve CRV amount claimable
    //     uint256 crvAmount = cvxRewardToken.earned(account);

    //     // Deduce cvxAmount bcs it's proportionnal
    //     //TODO Find the real factor
    //     uint256 cvxAmount = (crvAmount * 1212122222222) / 10 ** 18;

    //     // Retrieve extra rewards claimable, first part
    //     uint256 extraRewardsAmount = cvxRewardToken.extraRewardsLength();

    //     TokenAmount[] memory claimable = new TokenAmount[](extraRewardsAmount + 1);
    //     claimable[0] = TokenAmount({token: IERC20(CRV), amount: crvAmount});
    //     claimable[1] = TokenAmount({token: IERC20(CVX), amount: cvxAmount});

    //     for (uint256 i; i < extraRewardsAmount; i++) {
    //         ICvxRewardToken xtraRewardToken = ICvxRewardToken(cvxRewardToken.extraRewards(i));
    //         IStashTokenWrapper wrapper = IStashTokenWrapper(xtraRewardToken.rewardToken());
    //         IERC20Metadata realRewardToken = wrapper.token();
    //         // It's CVX
    //         if (i == 0) {
    //             claimable[1].amount += xtraRewardToken.earned(account);
    //         } else {
    //             claimable[i + 1] = TokenAmount({token: realRewardToken, amount: xtraRewardToken.earned(account)});
    //         }
    //     }

    //     return claimable;
    // }

    // function _getClaimableCurveGauge(address account, IGauge gauge) internal returns (TokenAmount[] memory) {
    //     uint256 rewardAmount = gauge.reward_count();
    //     TokenAmount[] memory claimable = new TokenAmount[](rewardAmount);

    //     for (uint256 i = 0; i < rewardAmount; i++) {
    //         address token = gauge.reward_tokens(i);
    //         claimable[i] = TokenAmount({token: IERC20(token), amount: gauge.claimable_reward(account, token)});
    //     }

    //     return claimable;
    // }

    // IAccountant constant accountant = IAccountant(0x93b4B9bd266fFA8AF68e39EDFa8cFe2A62011Ce0);
    // IProtocolController constant protocolController = IProtocolController(0x2d8BcE1FaE00a959354aCD9eBf9174337A64d4fb);
    // ICampaignRewardsDistributor constant campaignRewardsDistributor = ICampaignRewardsDistributor(0xD4898A378eA555595c4E7dbDE722B134a3F346D1);

    // function _getStakeDaoCRV(address account, address gauge, address[] memory extraRewards) internal returns (TokenAmount[] memory) {
    //     uint128 SCALING_FACTOR = 1e27;
    //     uint256 claimableCRV;
    //     address vault = protocolController.vault(gauge);
    //     uint256 extraRewardsLen = extraRewards.length;
    //     TokenAmount[] memory claimable = new TokenAmount[](1 + extraRewardsLen);

    //     // Get the account data for this gauge
    //     (uint128 balance, uint256 accountIntegral, uint256 pendingRewards) = accountant.accounts(vault, account);

    //     // If account has any rewards to claim for this vault, calculate the amount. Otherwise, skip.
    //     if (balance != 0 || pendingRewards != 0) {
    //         (uint256 vaultIntegral, , , , , , ) = accountant.vaults(vault);

    //         // If vault's integral is higher than account's integral, calculate the rewards and update the total.
    //         uint256 claimableAmount = pendingRewards;
    //         if (vaultIntegral > accountIntegral) {
    //             claimableAmount += ((vaultIntegral - accountIntegral) * balance) / SCALING_FACTOR;
    //         }

    //         // In any case, add the pending rewards to the total amount
    //         claimableCRV += claimableAmount;
    //     }

    //     claimable[0] = TokenAmount({token: IERC20(CRV), amount: claimableCRV});

    //     // Already claimed extra rewards
    //     uint256[] memory alreadyClaimed = new uint256[](extraRewardsLen);
    //     for (uint256 i; i < extraRewardsLen; i++) {
    //         address token = extraRewards[i];
    //         claimable[i + 1] = TokenAmount({token: IERC20(token), amount: campaignRewardsDistributor.claimed(account, token)});
    //     }

    //     return claimable;
    // }
}
