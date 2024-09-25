import "../ConvexMarketContext.sol";

contract DepositLlamaLendVaultAssetGov is ConvexMarketContext {

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_llamaLend_vault_asset_and_doDeposit(uint256 shareAmount) external {
        vm.assume(shareAmount > 1);
        // PREPARE
        address usr = makeAddr("User");
        dealLlamaVaultAsset(llamaVault, usr, shareAmount);
        vm.startPrank(usr);

        uint256 usrLlamaVaultBalanceBfr = llamaVault.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = llamaVault.balanceOf(address(splitter));

        uint256 usrRewardTokenBfr = cvxRewardToken.balanceOf(usr);
        uint256 gUSDRewardTokenBfr = cvxRewardToken.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToAssets(shareAmount);

        // ACTIONS
        llamaVault.approve(address(splitter), shareAmount);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount, false, true);

        // VERIFY

        // 100 llamaLendVault transfered
        assertEq(usrLlamaVaultBalanceBfr - llamaVault.balanceOf(usr), shareAmount);

        // 100 eth of CvxReward assets received by the gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBfr, shareAmount);
        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);

        // No LlamalendVault are sent to the splitter
        assertEq(llamaVault.balanceOf(address(splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward token are given to the user
        assertEq(usrRewardTokenBfr - cvxRewardToken.balanceOf(usr), 0);
    }

    function test_deposit_llamaLend_vault_asset_and_no_doDeposit(uint256 shareAmount) external {
        // PREPARE
        address usr = makeAddr("User");
        deal(address(llamaVault), usr, shareAmount);
        vm.startPrank(usr);

        uint256 usrLlamaVaultBalanceBfr = llamaVault.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = llamaVault.balanceOf(address(splitter));

        uint256 usrRewardTokenBfr = cvxRewardToken.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = cvxRewardToken.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToAssets(shareAmount);

        // ACTIONS
        llamaVault.approve(address(splitter), shareAmount);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount, false, false);

        // VERIFY

        // 100 eth of llamaLendVault transfered
        assertEq(usrLlamaVaultBalanceBfr - llamaVault.balanceOf(usr), shareAmount);

        // No CvxRewardTokens are given to the gUSD because we are not staking
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, 0);
        // No LlamalendVault are sent to the splitter
        assertEq(llamaVault.balanceOf(address(splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - cvxRewardToken.balanceOf(usr), 0);

        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);
    }

    function test_deposit_llamaLend_vault_asset_with_doDeposit_then_deposit_without_doDeposit(uint256 shareAmount) external {
        // PREPARE
        address usr = makeAddr("User");
        dealLlamaVaultAsset(llamaVault, usr, shareAmount);
        vm.startPrank(usr);

        // ACTIONS
        llamaVault.approve(address(splitter), shareAmount);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount, false, false);

        // PREPARE

        uint256 usrLlamaVaultBalanceBfr = llamaVault.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = llamaVault.balanceOf(address(splitter));

        uint256 usrRewardTokenBfr = cvxRewardToken.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = cvxRewardToken.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToAssets(shareAmount);

        // ACTIONS

        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount, false, true);

        // VERIFY

        // 100 llamaLendVault assets sent by the user
        assertEq(usrLlamaVaultBalanceBfr - llamaVault.balanceOf(usr), shareAmount);

        // 200 cvxReward assets received by gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, shareAmount);

        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);

        // No LlamalendVault are sent to the splitter
        assertEq(llamaVault.balanceOf(address(splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - cvxRewardToken.balanceOf(usr), 0);

    }
}
