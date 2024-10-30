// SPDX-License-Identifier: MIT
import "../../../contexts/TestWrapper.sol";

contract scvUSDCvxReverts is TestWrapper {
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_initialize_not_callable_after_init() external {
        vm.prank(usr1);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        scvUSD.initialize(usr1, "test", "test", splitter, llamaVault, usr1);
    }

    function test_mintSplitter_callable_only_by_lendSplitter() external {
        vm.prank(usr1);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr1));
        scvUSD.mintSplitter(usr1, 100 ether);
    }

    function test_mintAutoCompound_callable_only_by_autoCompounder() external {
        vm.prank(usr1);

        vm.expectRevert(abi.encodeWithSelector(scvUSDCvx.CallerNotAutoCompounder.selector, usr1));
        scvUSD.mintAutoCompound(100 ether);
    }

    function test_burn_callable_only_by_lendSplitter() external {
        vm.prank(usr1);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr1));
        scvUSD.burn(usr1, 100 ether);
    }
}
