// SPDX-License-Identifier: UNKNOWN
import "../ConvexMarketContext.sol";

contract DepositLendAssetStable is ConvexMarketContext {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_deposit_lend_asset_and_doDeposit() external {
        uint256 amountIn = 100 ether;
        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, amountIn);
        vm.startPrank(usr);

        uint256 usrLendAssetBalanceBfr = lendAsset.balanceOf(usr);
        uint256 gUSDRewardTokenBfr = cvxRewardToken.balanceOf(address(gUSD));
        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);
        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, true, true);

        // VERIFY
        assertEq(usrLendAssetBalanceBfr - lendAsset.balanceOf(usr), amountIn, "User sent crvUSD");
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBfr, sharesConverted, "CvxReward assets received by gUSD");
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted, "scvUSD is sent to user");
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0, "No gUSD should be minted");
    }

    function test_deposit_lend_asset_and_no_doDeposit() external {
        uint256 amountIn = 200 ether;

        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, amountIn);
        vm.startPrank(usr);

        uint256 usrLendAssetBalanceBfr = lendAsset.balanceOf(usr);

        uint256 gUSDRewardTokenBalanceBfr = cvxRewardToken.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);

        uint256 sharesConverted = llamaVault.convertToShares(amountIn);

        // ACTIONS
        lendAsset.approve(address(splitter), amountIn);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, true, false);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(usrLendAssetBalanceBfr - lendAsset.balanceOf(usr), amountIn);

        // An amount of scvUSD is minted to the user equivalent to the shares he put
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted);

        // No gUSD is minted to the user
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0);

        // No CvxReward assets are given to gUSD because  not staking
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, 0);
    }

    function test_deposit_lend_asset_with_doDeposit_then_deposit_without_doDeposit() external {
        // PREPARE
        address usr = makeAddr("User");
        deal(address(lendAsset), usr, 200 ether);
        vm.startPrank(usr);

        // ACTIONS
        lendAsset.approve(address(splitter), 200 ether);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, false);

        // PREPARE

        uint256 usrLendAssetBalanceBfr = lendAsset.balanceOf(usr);

        uint256 usrRewardTokenBfr = cvxRewardToken.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = cvxRewardToken.balanceOf(address(gUSD));

        uint256 sharesConverted = llamaVault.convertToShares(100 ether);

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);

        // ACTIONS

        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, true);

        // VERIFY

        // 100 llamaLendVault assets sent by the user
        assertEq(usrLendAssetBalanceBfr - lendAsset.balanceOf(usr), 100 ether);

        // "2 * sharesConverted" cvxReward assets received by gUSD
        assertEq(cvxRewardToken.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, sharesConverted * 2);

        // An amount of scvUSD is minted to the user equivalent to the shares he put
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted);

        // No gUSD is minted to the user
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0);

        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - cvxRewardToken.balanceOf(usr), 0);
    }
}
