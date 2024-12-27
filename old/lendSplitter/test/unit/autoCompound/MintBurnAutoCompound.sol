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

    function test_mint_scv_vault_asset(uint256 assetIn) external {
        assetIn = bound(assetIn, 1e16, 10_000_000 ether);
        uint256 shareLlamaVault = llamaVault.convertToShares(assetIn);

        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr1, autoCompoundInitAmount, false, true);

        vm.prank(usr1);
        scvUSD.transfer(address(scvUSDAutoCompound), autoCompoundInitAmount);

        assertEq(llamaVault.balanceOf(address(scvUSDAutoCompound)), 0, "No llamaVaultAsset asset on the autoCompound");
        assertEq(scvUSDAutoCompound.totalSupply(), 0, "Even after the donnation, the total share of the vault is still 0");

        uint256 expectedShareAutoComp = scvUSDAutoCompound.convertToShares(shareLlamaVault);

        uint256 autoCompoundBalUsr1 = scvUSDAutoCompound.balanceOf(usr1);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        Deposit GUSD with USER 3
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        // USER 3 Deposit some gUSD to generate yield
        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr3, assetIn * 2, true);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    Deposit scvUSD with USER 1
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        shareLlamaVault = llamaVault.convertToShares(assetIn);
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
        shareLlamaVault = llamaVault.convertToShares(assetIn);

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

        shareLlamaVault = llamaVault.convertToShares(assetIn);

        // DONATOR Donates and increase the index
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usr2, shareLlamaVault, false, true);
        vm.prank(usr2);
        scvUSD.transfer(address(scvUSDAutoCompound), shareLlamaVault);

        assertEq(scvUSD.balanceOf(address(scvUSDAutoCompound)), shareLlamaVault * 3 + autoCompoundInitAmount, "Verify scvUSD balance of the autoCompounder");

        // Skip some days to let rewards accumulate

        skip(30 days);

        uint256 valueFarmedInOneMonth = (gUSD.totalSupply() * llamaVault.lend_apr()) / (12 * 10 ** 18);
        // Remove processorFees
        uint256 valueFarmedInOneMonthMinusProcessorFees = (valueFarmedInOneMonth * (DENOMINATOR - processorFeePercentage)) / DENOMINATOR;

        vm.prank(processor);
        gUSD.processStableRewards(processor); // Process the rewards of the scvUSD

        assertApproxEqRel(
            llamaVault.convertToAssets(llamaVault.balanceOf(address(splitter))),
            valueFarmedInOneMonthMinusProcessorFees,
            2e16,
            "Value farmed by gUSD has to be accurate"
        );

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

        assertApproxEqAbs(
            llamaVault.balanceOf(address(splitter)),
            10 ** 11,
            10 ** 11,
            "Verify almost no more llamaVaultLP are on the splitter after indexation"
        );

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    USER 1 WITHDRAWS from AUTOCOMPOUNDER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        uint256 balanceCrvUSDUser1 = lendAsset.balanceOf(usr1);
        withdrawSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, scvUSDAutoCompound.balanceOf(usr1), true);

        assertEq(scvUSDAutoCompound.balanceOf(usr1), 0, "No more vault tokens");
        assertEq(scvUSD.balanceOf(usr1), 0, "No more scvUSD");

        assertGt(lendAsset.balanceOf(usr1) - balanceCrvUSDUser1, assetIn, "Should get more assets");
        assertApproxEqRel(lendAsset.balanceOf(usr1) - balanceCrvUSDUser1, (3 * assetIn) / 2, 2 * 10 ** 16, "User 1 retrieve more lend asset");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    USER 2 WITHDRAWS from AUTOCOMPOUNDER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        uint256 balanceCrvUSDUser2 = lendAsset.balanceOf(usr2);
        withdrawSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr2, scvUSDAutoCompound.balanceOf(usr2), true);

        assertEq(scvUSDAutoCompound.balanceOf(usr2), 0, "No more vault tokens");
        assertEq(scvUSD.balanceOf(usr2), 0, "Still no scvUSD");

        assertGt(lendAsset.balanceOf(usr2) - balanceCrvUSDUser2, assetIn);
        assertApproxEqRel(lendAsset.balanceOf(usr2) - balanceCrvUSDUser2, (3 * assetIn) / 2, 2 * 10 ** 16, "User 2 get around more of the half of the");

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    USER 3 WITHDRAWS from AUTOCOMPOUNDER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr3, gUSD.balanceOf(usr3));
        assertApproxEqAbs(lendAsset.balanceOf(usr3), assetIn * 2, 10, "Retrieve same amount of lendAsset as deposited on the beginning");
    }
}
