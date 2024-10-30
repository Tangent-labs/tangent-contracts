import "../../../contexts/TestWrapper.sol";

contract WithdrawLlamaLendVaultAssetGov is TestWrapper {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_withdraw_lend_asset(uint256 amountLendAssetDeposited) external {
        amountLendAssetDeposited = bound(amountLendAssetDeposited, 1e16, 5e24);
        // Performs a deposit with CRVUSD
        uint256 gUSDReceived = depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr2, amountLendAssetDeposited, true);

        uint256 sharesToBurn = llamaVault.convertToShares(gUSDReceived);

        withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr2, gUSD.balanceOf(usr2));

        assertEq(cvxRewardToken.balanceOf(address(gUSD)), gUSD.getStreamableShares());
    }

    function test_withdraw_llamalend_vault_asset(
        uint256 sharesDeposited1,
        uint256 sharesDeposited2,
        uint256 amountDepositedUsr2,
        uint256 gUSDWithdrawn1
    ) external {
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-=
                DO 2 deposits in order to have some LLAMA LP and CVX REWARD TOKENS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-= */
        sharesDeposited1 = bound(sharesDeposited1, 1e20, 5e30);
        sharesDeposited2 = bound(sharesDeposited2, 1e20, 5e30);
        amountDepositedUsr2 = bound(amountDepositedUsr2, 1e16, 5e24);

        // Performs a deposit with LendASset
        uint256 equivalentAssetDeposited1 = llamaVault.convertToAssets(sharesDeposited1);

        uint256 gUSDReceived1 = depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesDeposited1, true);

        assertERC20Tracking();

        uint256 equivalentAssetDeposited2 = llamaVault.convertToAssets(sharesDeposited2);
        uint256 gUSDReceived2 = depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, sharesDeposited2, false);

        uint256 shareDepositedUsr2 = llamaVault.convertToShares(amountDepositedUsr2);
        (, uint256 scvUSDReceived) = depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr2, amountDepositedUsr2, false, true);

        assertEq(gUSD.socFeePending(), 0, "No pending soc Fee after staking");

        skip(7 days);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                WITHDRAW A PART OF THE POSITION
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        gUSDWithdrawn1 = bound(gUSDWithdrawn1, 2, gUSD.balanceOf(usr1) - 2);
        uint256 share = llamaVault.convertToShares(gUSDWithdrawn1);

        withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, gUSDWithdrawn1);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW WHAT'S LEFT
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        skip(7 days);

        uint256 user1gUSDBalance = gUSD.balanceOf(usr1);
        share = llamaVault.convertToShares(user1gUSDBalance);

        vm.prank(usr1);
        withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, user1gUSDBalance);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REDEEM VAULT LP TO CRVUSD
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr1);
        llamaVault.redeem(llamaVault.balanceOf(usr1));
        vm.stopPrank();

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    PROCESS STABLE REWARDS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        uint256 streamedAmount = lendAsset.balanceOf(address(splitter));
        gUSD.processStableRewards(usr2);
        streamedAmount = lendAsset.balanceOf(address(splitter)) - streamedAmount - splitter.daoFeeForToken(lendAsset);

        // Verify that there are no more llamaVault LP and CvxRewardToken after the everyone has withdrawn and the processReward occured
        assertEq(
            llamaVault.balanceOf(address(gUSD)) + cvxRewardToken.balanceOf(address(gUSD)),
            scvUSDReceived,
            "What left in staking should be equals to what has been deposited on scvUSD"
        );

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      CLAIM ALL REWARDS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        skip(7 days);
        vm.startPrank(usr2);
        uint256 _amountDepositedUsr2 = amountDepositedUsr2;

        uint256 crvUsdClaimedUser2 = lendAsset.balanceOf(usr2);
        splitter.claimSimple(address(scvUSD));
        // 0.5% of offset
        assertApproxEqRel(streamedAmount, lendAsset.balanceOf(usr2) - crvUsdClaimedUser2, 50e15);
        vm.stopPrank();

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      WITHDRAW  STABLE STAKING
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        crvUsdClaimedUser2 = lendAsset.balanceOf(usr2);
        withdrawSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr2, scvUSD.balanceOf(usr2), false);
        assertApproxEqRel(
            lendAsset.balanceOf(usr2) - crvUsdClaimedUser2,
            _amountDepositedUsr2,
            1e16,
            "Should retrieve approximatly the same amount of lendAsset before depositing"
        );
        // assertApproxEqRel(crvUsdClaimedUser2, _amountDepositedUsr2, 50e15);
    }
}
