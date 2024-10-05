// SPDX-License-Identifier: MIT
import "../convex/ConvexMarketContext.sol";

contract SplitterTokenFees is ConvexMarketContext {
    address usr = makeAddr("User");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }

    // getAndUpdateRewards
    function test_addNewReward() external {
        vm.prank(owner);

        gUSD.addNewReward(AddrClassicERC20.TOKEN_SDT, ISplitterToken.Fees({processorFeePercentage: 400, daoFeePercentage: 1_500}));

        assertEq(gUSD.getRewardTokens().length, 3, "New Reward token has been added");

        (uint256 processorFee, uint256 daoFees) = gUSD.fees(2);
        assertEq(processorFee, 400, "Processor fee is setup");
        assertEq(daoFees, 1_500, "Dao fee is setup");

        (uint128 lastUpdateTime, uint128 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored) = gUSD.rewardData(AddrClassicERC20.TOKEN_SDT);
        assertEq(lastUpdateTime, block.timestamp, "Last update time is setup");
        assertEq(periodFinish, block.timestamp, "Period finish is setup");
        assertEq(rewardRate, 0, "Reward rate is still 0 because no reward have been processed");
        assertEq(rewardPerTokenStored, 0, "Reward per token is still 0 because no reward have been processed");
    }

    function test_setFees() external {
        vm.prank(owner);

        ISplitterToken.Fees[] memory newFees = new ISplitterToken.Fees[](1);
        newFees[0] = ISplitterToken.Fees({processorFeePercentage: 400, daoFeePercentage: 1_500});

        scvUSD.setFees(newFees);

        (uint256 processorFee, uint256 daoFees) = scvUSD.fees(0);
        assertEq(processorFee, 400, "New processor fee is setup");
        assertEq(daoFees, 1_500, "New dao fee is setup");
    }
}
