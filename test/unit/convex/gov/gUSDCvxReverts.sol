// SPDX-License-Identifier: MIT
import "../../../contexts/ConvexMarketContext.sol";

contract gUSDCvxReverts is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_initialize_not_callable_after_init() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        gUSD.initialize(usr, "test", "test", splitter, cvxRewardToken, llamaVault, cvxVaultToken, scvUSD);
    }

    function test_mint_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.mint(usr, 100 ether, llamaVault, 12, false);
    }

    function test_burn__callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.burn(usr, 100 ether, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, llamaVault);
    }

    function test_withdraw_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.withdraw(100 ether, usr, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, llamaVault);
    }

    function test_claimSCVUSDRewards_callable_only_by_scvUSD() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.withdraw(100 ether, usr, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, llamaVault);
    }
}
