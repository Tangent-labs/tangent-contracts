// SPDX-License-Identifier: UNKNOWN
import "./ConvexMarketContext.sol";

contract BorrowRepayLoan is ConvexMarketContext {
    address borrower = makeAddr("Borrower");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_create_a_loan_and_repay_it() external {
        uint256 ppsBefore = llamaVault.pricePerShare();
        uint256 totalBefore = llamaVault.totalAssets();
        uint256 totalAssetsBefore = crvController.total_debt();
        uint256 controllerBalance = lendAsset.balanceOf(address(crvController));

        uint256 debt = 10 ** 17;
        vm.startPrank(borrower);
        IERC20Metadata collat = IERC20Metadata(llamaVault.collateral_token());

        uint256 decimals = collat.decimals();

        deal(address(collat), borrower, 10 ** decimals);
        collat.approve(address(crvController), 10 ** decimals);
        crvController.create_loan(10 ** decimals, debt, 4);
        skip(14 days);
        uint256 ppsAfter = llamaVault.pricePerShare();
        uint256 totalAfter = llamaVault.totalAssets();
        uint256 totalAssetsAfter = crvController.total_debt();
        uint256 controllerBalance1 = lendAsset.balanceOf(address(crvController));

        lendAsset.approve(address(crvController), debt);
        crvController.repay(debt);
        skip(14 days);

        uint256 ppsAfterr = llamaVault.pricePerShare();
        uint256 totalAfterr = llamaVault.totalAssets();
        uint256 totalAssetsAfterr = crvController.total_debt();
        uint256 controllerBalance2 = lendAsset.balanceOf(address(crvController));

        lendAsset.approve(address(llamaVault), 10 ** 20);
        deal(address(lendAsset), borrower, 10 ** 20);

        llamaVault.deposit(10 ** 20);
        skip(14 days);

        assertEq(totalAssetsBefore + controllerBalance, totalBefore);
        assertEq(totalAssetsAfter + controllerBalance1, totalAfter);
        assertEq(totalAssetsAfterr + controllerBalance2, totalAfterr);
    }
}
