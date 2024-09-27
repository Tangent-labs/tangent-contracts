// SPDX-License-Identifier: MIT
import "../convex/ConvexMarketContext.sol";

contract SplitterTokenReverts is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    // getAndUpdateRewards
    function test_getAndUpdateRewards_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.getAndUpdateRewards(usr);
    }

    function test_addNewReward_callable_only_by_owner() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.addNewReward(IERC20(usr), ICurveLendSplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000}));
    }

    function test_addRewards_with_token_already_a_reward() external {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.RewardAlreadyAdded.selector, address(AddrClassicERC20.TOKEN_CRV)));
        gUSD.addNewReward(AddrClassicERC20.TOKEN_CRV, ICurveLendSplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000}));
    }

    function test_setFees_callable_only_by_owner() external {
        vm.prank(usr);

        ICurveLendSplitterToken.Fees[] memory newFeeSettings = new ICurveLendSplitterToken.Fees[](2);
        newFeeSettings[0] = ICurveLendSplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000});
        newFeeSettings[1] = ICurveLendSplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000});

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.setFees(newFeeSettings);
    }

    function test_setFees_with_a_fee_array_not_equal_to_fee_length() external {
        ICurveLendSplitterToken.Fees[] memory newFeeSettings = new ICurveLendSplitterToken.Fees[](3);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.WrongFeesPercetageLength.selector, 3, 2));
        gUSD.setFees(newFeeSettings);
    }

    function test_recoverTokens_callable_only_by_owner() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.recoverToken(IERC20(usr), 12);
    }

    function test_recoverTokens_on_a_reward_token() external {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.CantWithdrawRewardToken.selector, address(AddrClassicERC20.TOKEN_CRV)));

        gUSD.recoverToken(AddrClassicERC20.TOKEN_CRV, 12);
    }

    // REWARDS & FEES
}
