import "../../contexts/TestWrapper.sol";

contract MintBurnAutoCompound is TestWrapper {
    uint256 autoCompoundInitAmount = 1 ether;

    uint256 processorFeePercentage;
    uint256 daoFeePercentage;

    uint256 DENOMINATOR;

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();

        (processorFeePercentage, daoFeePercentage) = scvUSD.fees(0);
        DENOMINATOR = scvUSD.DENOMINATOR();
    }

    function test_mint_scv_vault_asset() external {
        uint256 assetIn = 1_000 ether;
        uint256 shareLlamaVault = llamaVault.previewDeposit(assetIn);

        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, autoCompoundInitAmount, false, true);

        vm.prank(usr1);
        scvUSD.transfer(address(scvUSDAutoCompound), autoCompoundInitAmount);

        assertEq(llamaVault.balanceOf(address(scvUSDAutoCompound)), 0, "No llamaVaultAsset asset on the autoCompound");
        assertEq(scvUSDAutoCompound.totalSupply(), 0, "Even after the donnation, the total share of the vault is still 0");

        deal(address(lendAsset), usr1, assetIn * 2);

        uint256 expectedShareAutoComp = scvUSDAutoCompound.convertToShares(shareLlamaVault);

        uint256 autoCompoundBalUsr1 = scvUSDAutoCompound.balanceOf(usr1);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        Deposit GUSD with USER 1
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        uint256 gUSDToMint = llamaVault.convertToAssets(llamaVault.convertToShares(assetIn * 2));
        // USER 1 Deposit some gUSD to generate yield
        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, assetIn * 2, true);

        assertEq(gUSD.balanceOf(usr1), gUSDToMint, "Mints the correct amount of gUSD");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    Deposit scvUSD with USER 1
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        autoCompoundBalUsr1 = scvUSDAutoCompound.balanceOf(usr1);
        uint256 autoCompoundShareToMint = scvUSDAutoCompound.convertToShares(shareLlamaVault);

        // Get scvUSD
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, shareLlamaVault, true, true);

        assertEq(scvUSD.balanceOf(address(scvUSDAutoCompound)), shareLlamaVault + autoCompoundInitAmount, "Verify scvUSD balance of the autoCompounder");

        assertEq(scvUSDAutoCompound.totalSupply(), scvUSDAutoCompound.balanceOf(usr1), "Balance of the only user equals to the totalSupply of the vault");

        assertEq(scvUSDAutoCompound.balanceOf(usr1), autoCompoundShareToMint, "Cayapou");

        expectedShareAutoComp = scvUSDAutoCompound.convertToShares(shareLlamaVault);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
            Deposit scvUSD with USER 2 without AUTOCOMPOUND
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // Get scvUSD
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr2, shareLlamaVault, false, true);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                Stake scvUSD in Autocompouund with User 2
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        vm.startPrank(usr2);
        scvUSD.approve(address(scvUSDAutoCompound), MAX_UINT);
        // Stake scvUSD
        scvUSDAutoCompound.deposit(shareLlamaVault, usr2);
        vm.stopPrank();

        assertEq(llamaVault.balanceOf(usr2), 0, "All LlamaVault LP taken from user 2");
        assertEq(scvUSDAutoCompound.totalSupply(), expectedShareAutoComp + expectedShareAutoComp, "Some autoCompound token should be minted ");
        assertEq(scvUSDAutoCompound.balanceOf(usr2), expectedShareAutoComp, "Some autoCompound token should be minted to User 2");
        assertEq(scvUSDAutoCompound.balanceOf(usr2), scvUSDAutoCompound.balanceOf(usr1), "Share in the autoCompounder are the same");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        DONATES some SCVUSD
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // DONATOR Donates and increase the index
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr2, shareLlamaVault, false, true);
        vm.prank(usr2);
        scvUSD.transfer(address(scvUSDAutoCompound), shareLlamaVault);

        assertEq(scvUSD.balanceOf(address(scvUSDAutoCompound)), shareLlamaVault * 3 + autoCompoundInitAmount, "Verify scvUSD balance of the autoCompounder");

        // Skip some days to let rewards accumulate

        skip(30 days);

        uint256 valueFarmed = (gUSD.totalSupply() * llamaVault.lend_apr()) / (12 * 10 ** 18);
        // Remove processorFees
        valueFarmed = (valueFarmed * (DENOMINATOR - processorFeePercentage)) / DENOMINATOR;

        vm.prank(processor);
        gUSD.processStableRewards(processor); // Process the rewards of the scvUSD

        assertApproxEqRel(llamaVault.convertToAssets(llamaVault.balanceOf(address(splitter))), valueFarmed, 2e16, "Value farmed by gUSD has to be accurate");

        // Let all reward stream
        skip(8 days);

        // Remove all fees from the splitter for easier calculation
        IERC20[] memory tokensToClaim = new IERC20[](1);
        tokensToClaim[0] = llamaVault;

        vm.prank(splitter.feeTreasury());
        splitter.withdrawFees(tokensToClaim);

        // Do the indexation of the autocompounder

        uint256 expectedSCVUSD = llamaVault.balanceOf(address(splitter));
        uint256 scvUSDBalanceAutoCompoundBefore = scvUSD.balanceOf(address(scvUSDAutoCompound));

        vm.prank(owner);
        scvUSDAutoCompound.indexation();

        assertApproxEqAbs(
            scvUSD.balanceOf(address(scvUSDAutoCompound)) - scvUSDBalanceAutoCompoundBefore,
            expectedSCVUSD,
            1e15,
            "Right amounf of scvUSD deposited on the Vault"
        );

        assertApproxEqAbs(llamaVault.balanceOf(address(splitter)), 10 ** 7, 10 ** 7, "Verify almost no more crvUSD are on the splitter");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    USER 1 WITHDRAWS from AUTOCOMPOUNDER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr1);
        uint256 balanceCrvUSDUser1 = lendAsset.balanceOf(usr1);

        splitter.withdrawSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSDAutoCompound.balanceOf(usr1), true);
        vm.stopPrank();

        assertEq(scvUSDAutoCompound.balanceOf(usr1), 0, "No more vault tokens");
        assertEq(scvUSD.balanceOf(usr1), 0, "No more scvUSD");
        assertApproxEqAbs(lendAsset.balanceOf(usr1) - balanceCrvUSDUser1, 1_500 ether, 20 ether, "User 1 retrieve more lend asset");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    USER 2 WITHDRAWS from AUTOCOMPOUNDER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr2);
        uint256 balanceCrvUSDUser2 = lendAsset.balanceOf(usr2);
        splitter.withdrawSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSDAutoCompound.balanceOf(usr2), true);

        assertEq(scvUSDAutoCompound.balanceOf(usr2), 0, "No more vault tokens");
        assertEq(scvUSD.balanceOf(usr2), 0, "Still no scvUSD");
        assertApproxEqAbs(lendAsset.balanceOf(usr2) - balanceCrvUSDUser2, 1_500 ether, 20 ether, "User 2 retrieve more lend asset");

        vm.stopPrank();

        withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, gUSD.balanceOf(usr1));
        // assertApproxEqAbs(lendAsset.balanceOf(usr1), 1_500 ether, 300, "Retrieve more llamaLendVault");

        // uint256 user1FullAssets = scvUSDAutoCompound.maxWithdraw(usr1);
        // uint256 user2FullAssets = scvUSDAutoCompound.maxWithdraw(usr2);

        // assertEq(scvUSDAutoCompound.balanceOf(usr1), 0, "Some autoCompound token should be minted to User 1");
        // assertEq(scvUSDAutoCompound.balanceOf(usr2), 0, "Some autoCompound token should be minted to User 1");
        // // assertApproxEqAbs(user1FullAssets, 150 ether, 1, "User 1 should have the the half of the distributed rewards");

        // assertEq(user1FullAssets, user2FullAssets);
    }
}
