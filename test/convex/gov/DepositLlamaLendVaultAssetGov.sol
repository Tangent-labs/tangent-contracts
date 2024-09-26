// SPDX-License-Identifier: MIT
import "../ConvexMarketContext.sol";

contract DepositLlamaLendVaultAssetGov is ConvexMarketContext {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_llamaLend_vault_asset_and_doDeposit(uint256 shareAmount) external {
        shareAmount = bound(shareAmount, 1e20, 5e30);

        address usr = makeAddr("User");
        shareAmount = dealLlamaVaultAsset(llamaVault, usr, shareAmount);
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
        shareAmount = bound(shareAmount, 1e20, 5e30);
        // PREPARE
        address usr = makeAddr("User");
        shareAmount = dealLlamaVaultAsset(llamaVault, usr, shareAmount);
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

    function test_deposit_llamaLend_vault_asset_with_doDeposit_then_deposit_without_doDeposit(uint256 shareAmount1, uint256 shareAmount2) external {
        shareAmount1 = bound(shareAmount1, 1e20, 5e30);
        shareAmount2 = bound(shareAmount2, 1e20, 5e30);

        // PREPARE
        address usr = makeAddr("User");
        dealLlamaVaultAsset(llamaVault, usr, shareAmount1 + shareAmount2);
        vm.startPrank(usr);

        // ACTIONS
        llamaVault.approve(address(splitter), shareAmount1);
        console.log("Balance LlamaVault", llamaVault.balanceOf(usr));
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount1, false, false);

        // PREPARE

        uint256 usrLlamaVaultBalanceBfr = llamaVault.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = cvxRewardToken.balanceOf(address(gUSD));
        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToAssets(shareAmount2);

        // ACTIONS
        llamaVault.approve(address(splitter), shareAmount2);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, shareAmount2, false, true);

        // VERIFY

        assertEq(usrLlamaVaultBalanceBfr - llamaVault.balanceOf(usr), shareAmount2, "LlamaLendVault asset sent by the user");
        assertEq(
            cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr,
            shareAmount1 + shareAmount2,
            "CvxRewardAsset for both deposit received by gUSD"
        );
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted, "gUSD corresponding to the second deposit received by the user");
    }
}
