// SPDX-License-Identifier: MIT
import "../../../contexts/ConvexMarketContext.sol";

contract scvUSDCvxReverts is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_initialize_not_callable_after_init() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        scvUSD.initialize(usr, "test", "test", splitter, llamaVault, usr);
    }

    function test_mintSplitter_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        scvUSD.mintSplitter(usr, 100 ether);
    }

    function test_mintAutoCompound_callable_only_by_autoCompounder() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(scvUSDCvx.CallerNotAutoCompounder.selector, usr));
        scvUSD.mintAutoCompound(100 ether);
    }

    function test_burn_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        scvUSD.burn(usr, 100 ether);
    }
}
