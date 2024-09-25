import "../ConvexMarketContext.sol";

contract WithdrawLlamaLendVaultAssetGov is ConvexMarketContext {
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_withdraw_lend_asset(uint256 amountLendAssetDeposited) external {
        vm.startPrank(usr2);
        amountLendAssetDeposited = bound(amountLendAssetDeposited, 1e16, 5e24);

        // Performs a deposit with CRVUSD
        deal(address(lendAsset), usr2, amountLendAssetDeposited);
        lendAsset.approve(address(splitter), amountLendAssetDeposited);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountLendAssetDeposited, false, true);
        // PREPARE

        uint256 usrLendAssetBalanceBfr = lendAsset.balanceOf(usr2);


        // ACTIONS
        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSD.balanceOf(usr2), false);

        // VERIFY
        assertApproxEqRel(lendAsset.balanceOf(usr2) - usrLendAssetBalanceBfr , amountLendAssetDeposited, 1e5);


        assertEq(cvxRewardToken.balanceOf(address(gUSD)), scvUSD.getStreamableShares());



    }

    function test_withdraw_llamalend_vault_asset(uint256 sharesDeposited1, uint256 sharesDeposited2, uint256 amountDepositedUsr2, uint256 withdrawnAmount1) external {

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-=
                DO 2 deposits in order to have some LLAMA LP and CVX REWARD TOKENS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-= */
        sharesDeposited1 = bound(sharesDeposited1, 1e20, 5e30);
        sharesDeposited2 = bound(sharesDeposited2, 1e20, 5e30);
        amountDepositedUsr2 = bound(amountDepositedUsr2, 1e16, 5e24);
        // Performs a deposit with LendASset

        uint256 initialLendAssetEquivalent = dealLlamaVaultAsset(llamaVault, usr1, sharesDeposited1) +
            dealLlamaVaultAsset(llamaVault, usr1, sharesDeposited2);
        deal(address(lendAsset), usr2, amountDepositedUsr2);

        vm.startPrank(usr1);
        llamaVault.approve(address(splitter), UINT256_MAX);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, sharesDeposited1, false, true);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, sharesDeposited2, false, false);


        uint256 shareDepositedUsr2 = llamaVault.convertToShares(amountDepositedUsr2);
        vm.stopPrank();
        vm.startPrank(usr2);
        lendAsset.approve(address(splitter), UINT256_MAX);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountDepositedUsr2, true, true);
        vm.stopPrank();

        skip(7 days);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                WITHDRAW A PART OF THE POSITION
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));

        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        uint256 totalSupplyGUSD = gUSD.totalSupply();
        uint256 usrGUSDBalance = gUSD.balanceOf(usr1);

        // Verify that everythin has been removed from user
        assertEq(balOfUsr1LlamaLp, 0);

        // Bound the amount to withdraw between a small value and the balance of the user
        withdrawnAmount1 = bound(withdrawnAmount1, 2, gUSD.balanceOf(usr1) - 2);
        uint256 share = llamaVault.convertToShares(withdrawnAmount1);

        vm.startPrank(usr1);
        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, withdrawnAmount1, false);

        // User receives LlamaLend Asset
        assertEq(llamaVault.balanceOf(address(usr1)) - balOfUsr1LlamaLp, share);
        // gUSD is burnt from user
        assertEq(usrGUSDBalance - gUSD.balanceOf(usr1), withdrawnAmount1);
        skip(7 days);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW WHAT'S LEFT 
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // LLAMALEND
        totalSupplyLlamaLp = llamaVault.totalSupply();
        balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));

        // CVX REWARD
        totalSupplyCvxReward = cvxRewardToken.totalSupply();
        balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        totalSupplyGUSD = gUSD.totalSupply();
        usrGUSDBalance = gUSD.balanceOf(usr1);

        share = llamaVault.convertToShares(usrGUSDBalance);
        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usrGUSDBalance, false);

        // User receives LlamaLend Asset
        assertEq(llamaVault.balanceOf(address(usr1)) - balOfUsr1LlamaLp, share);
        // gUSD is burnt from user
        assertEq(usrGUSDBalance - gUSD.balanceOf(usr1), usrGUSDBalance);

        uint256 balOfUsr1LendAsset = lendAsset.balanceOf(usr1);
        balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REDEEM VAULT LP TO CRVUSD  
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        llamaVault.redeem(balOfUsr1LlamaLp);

        // Verify that we withdraw approx the same amount of crvUSD at 0.1%
        assertApproxEqRel(lendAsset.balanceOf(usr1) - balOfUsr1LendAsset, initialLendAssetEquivalent, 1e16);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    PROCESS STABLE REWARDS  
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        uint256 streamedAmount = lendAsset.balanceOf(address(splitter));
        scvUSD.processRewards();
        streamedAmount = lendAsset.balanceOf(address(splitter)) - streamedAmount - splitter.daoFeeForToken(lendAsset);

        // Verify that there are no more llamaVault LP and CvxRewardToken after the everyone has withdrawn and the processReward occured
        assertEq(llamaVault.balanceOf(address(gUSD)) + cvxRewardToken.balanceOf(address(gUSD)), shareDepositedUsr2);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      CLAIM ALL REWARDS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        skip(7 days);
        uint256 _amountDepositedUsr2 = amountDepositedUsr2;

        uint256 crvUsdClaimedUser2 = lendAsset.balanceOf(usr2);
        splitter.claimSimple(address(scvUSD), usr2);
        // 0.5% of offset
        assertApproxEqRel(streamedAmount, lendAsset.balanceOf(usr2) - crvUsdClaimedUser2, 50e15);
        vm.stopPrank();
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                      WITHDRAW THE STABLE STAKING
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        vm.startPrank(usr2);

        crvUsdClaimedUser2 = lendAsset.balanceOf(usr2);
        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSD.balanceOf(usr2), true);
        assertApproxEqRel(lendAsset.balanceOf(usr2) - crvUsdClaimedUser2 , _amountDepositedUsr2, 1e16);
        // assertApproxEqRel(crvUsdClaimedUser2, _amountDepositedUsr2, 50e15);

    }


}
