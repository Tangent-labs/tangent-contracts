// SPDX-License-Identifier: MIT
import "../../contexts/ConvexMarketContext.sol";

contract SplitterTokenReverts is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    function test_getAndUpdateRewards_callable_only_by_lendSplitter() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
        gUSD.getAndUpdateRewards(usr);
    }

    function test_addNewReward_callable_only_by_owner() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.addNewReward(IERC20(usr), ISplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000}));
    }

    function test_addRewards_with_token_already_a_reward() external {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SplitterToken.RewardAlreadyAdded.selector, address(AddrClassicERC20.TOKEN_CRV)));
        gUSD.addNewReward(AddrClassicERC20.TOKEN_CRV, ISplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000}));
    }

    function test_setFees_callable_only_by_owner() external {
        vm.prank(usr);

        ISplitterToken.Fees[] memory newFeeSettings = new ISplitterToken.Fees[](2);
        newFeeSettings[0] = ISplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000});
        newFeeSettings[1] = ISplitterToken.Fees({processorFeePercentage: 1000, daoFeePercentage: 1000});

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.setFees(newFeeSettings);
    }

    function test_setFees_with_a_fee_array_not_equal_to_fee_length() external {
        ISplitterToken.Fees[] memory newFeeSettings = new ISplitterToken.Fees[](3);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SplitterToken.WrongFeesPercetageLength.selector, 3, 2));
        gUSD.setFees(newFeeSettings);
    }

    function test_recoverTokens_callable_only_by_owner() external {
        vm.prank(usr);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", usr));
        gUSD.recoverToken(IERC20(usr), 12);
    }

    function test_recoverTokens_on_a_reward_token() external {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SplitterToken.CantWithdrawRewardToken.selector, address(AddrClassicERC20.TOKEN_CRV)));

        gUSD.recoverToken(AddrClassicERC20.TOKEN_CRV, 12);
    }

    function test_withdraw_too_much() external {
        vm.prank(usr);
        vm.expectRevert(abi.encodeWithSelector(SplitterToken.CantBurnThatMuchFor.selector, address(usr)));

        splitter.withdrawGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 10000);
    }
}
