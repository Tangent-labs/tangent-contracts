// SPDX-License-Identifier: MIT
import "../ConvexMarketContext.sol";

contract scvUSDCvxReverts is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_initialize_not_callable_after_init() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        scvUSD.initialize("test", "test", splitter, llamaVault, usr);
    }

    function test_mint_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NotLendRewardSplitter.selector, usr));
        scvUSD.mint(usr, 100 ether);
    }

    function test_burn_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NotLendRewardSplitter.selector, usr));
        scvUSD.burn(usr, 100 ether);
    }
}
