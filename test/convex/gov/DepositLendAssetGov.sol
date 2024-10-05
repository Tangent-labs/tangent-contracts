import "../ConvexMarketContext.sol";

contract DepositLendAssetGov is ConvexMarketContext {
    address usr = makeAddr("User");

    uint256 totalSupplyGUSD;

    uint256 usrGUSDBalance;

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_lend_asset_and_doDeposit(uint120 amountIn) external {
        vm.assume(amountIn > 1);

        // PREPARE
        deal(address(lendAsset), usr, amountIn);
        vm.startPrank(usr);
        // CRVUSD
        uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
        uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        usrGUSDBalance = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn);
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, true);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), amountIn);
        // 100 crvUSD received on CRVUSD Controller
        assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, amountIn);

        // LlamaLend LP is minted ( totalSupply )
        assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted);
        // LlamaLend LP is sent the corresponding gauge
        assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, sharesConverted);
        // LlamaLend LP is not sent to gUSD
        assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, 0);

        // Cvx Rewards token are minted
        assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, sharesConverted);
        // Cvx Rewards token are sent to gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, sharesConverted);

        // gUSD are minted
        assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, amountIn, 1);
        // gUSD are sent to user
        assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, amountIn, 1);
    }

    // function test_deposit_lend_asset_and_no_doDeposit(uint120 amountIn) external {
    //     vm.assume(amountIn > 1);
    //     // PREPARE
    //     address usr = makeAddr("User");
    //     deal(address(lendAsset), usr, amountIn);
    //     vm.startPrank(usr);
    //     // CRVUSD
    //     uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
    //     uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
    //     // LLAMALEND
    //     uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
    //     uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
    //     uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
    //     // CVX REWARD
    //     uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
    //     uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
    //     // GUSD
    //     uint256 totalSupplyGUSD = gUSD.totalSupply();
    //     uint256 usrGUSDBalance = gUSD.balanceOf(usr);

    //     uint256 sharesConverted = llamaVault.convertToShares(amountIn);

    //     // ACTIONS
    //     lendAsset.approve(address(splitter), amountIn);
    //     splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false);

    //     // VERIFY

    //     // amountIn crvUSD sent by usr
    //     assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), amountIn);
    //     // amountIn crvUSD received on CRVUSD Controller
    //     assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, amountIn);

    //     // LlamaLend LP is minted ( totalSupply )
    //     assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted);
    //     // LlamaLend LP is sent to gUSD
    //     assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, sharesConverted);
    //     // LlamaLend LP is is not staked in CRV gauge
    //     assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, 0);

    //     // Cvx Rewards token are not minted
    //     assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, 0);
    //     // Cvx Rewards token are not sent to gUSD
    //     assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, 0);

    //     // gUSD are minted
    //     assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, amountIn, 1);
    //     // gUSD are sent to user
    //     assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, amountIn, 1);
    // }

    function test_deposit_lend_asset_without_doDeposit_then_deposit_with_doDeposit(uint120 randomAmount) external {
        uint256 amountIn = randomAmount / 2;
        vm.assume(amountIn > 1);

        // PREPARE

        deal(address(lendAsset), usr, randomAmount);
        vm.startPrank(usr);

        // CRVUSD
        uint256 balanceOfUserCrvUSD = lendAsset.balanceOf(usr);
        uint256 balanceOfCRVUSDControllerCrvUSD = lendAsset.balanceOf(address(crvController));
        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfCrvGaugeLlamaLp = llamaVault.balanceOf(address(crvGauge));
        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        usrGUSDBalance = gUSD.balanceOf(usr);
        uint256 expectedgUSDMinted = llamaVault.convertToShares(amountIn);

        uint256 socFeeAcc = (expectedgUSDMinted * gUSD.socFeePercentage()) / gUSD.DENOMINATOR();

        expectedgUSDMinted = llamaVault.convertToAssets(llamaVault.convertToShares(amountIn) - socFeeAcc);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn * 2);
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false);

        assertEq(gUSD.balanceOf(usr), expectedgUSDMinted, "gUSD amount without staking takes fee");
        assertEq(gUSD.socFeePending(), socFeeAcc, "Verify that socFees are updated");

        // Pass random days
        skip(bound(vm.randomUint(), 0, 30) * 86_400);

        expectedgUSDMinted = llamaVault.convertToAssets(llamaVault.convertToShares(amountIn) + gUSD.socFeePending());
        // ACTIONS
        usrGUSDBalance = gUSD.balanceOf(usr);
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, true);

        assertEq(gUSD.socFeePending(), 0, "Soc Fee has to be reset");

        assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, expectedgUSDMinted, 1000, "gUSD amount without staking retrieves socFees");

        // // VERIFY

        // // 2 * amountIn crvUSD sent by usr
        // assertEq(balanceOfUserCrvUSD - lendAsset.balanceOf(usr), 2 * amountIn, "User sent lendAsset");
        // // 2 * amountIn crvUSD received on CRVUSD Controller
        // assertEq(lendAsset.balanceOf(address(crvController)) - balanceOfCRVUSDControllerCrvUSD, 2 * amountIn, "CRVUSD Controller received the lendAsset ");

        // // LlamaLend LP is minted ( totalSupply )
        // assertEq(llamaVault.totalSupply() - totalSupplyLlamaLp, sharesConverted, "More LlamaLendLP is minted");
        // // LlamaLend LP is not sent to gUSD
        // assertEq(llamaVault.balanceOf(address(gUSD)) - balOfGUSDLlamaLp, 0, "No LlamaLendLP is on the gUSD because the second deposit staked in CvxReward ");
        // // LlamaLend LP is staked in CRV gauge
        // assertEq(llamaVault.balanceOf(address(crvGauge)) - balOfCrvGaugeLlamaLp, sharesConverted, "Vault LP are staked in CRV Gauge");

        // // Cvx Rewards token not minted
        // assertEq(cvxRewardToken.totalSupply() - totalSupplyCvxReward, sharesConverted, "CVX Reward tokens are minted");
        // // Cvx Rewards token not sent to gUSD
        // assertEq(cvxRewardToken.balanceOf(address(gUSD)) - balOfGUSDCvxReward, sharesConverted, "CVX Reward tokens are received by gUSD");

        // // gUSD are minted
        // assertApproxEqAbs(gUSD.totalSupply() - totalSupplyGUSD, amountIn * 2, 2, "More gUSD are minted");
        // // gUSD are sent to user
        // assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalance, amountIn * 2, 2, "gUSD are received by the USER");
    }
}
