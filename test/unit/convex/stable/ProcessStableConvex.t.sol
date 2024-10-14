import "../../../contexts/TestWrapper.sol";

contract ProcessStableConvex is TestWrapper {
    uint256 processorFees;
    uint256 daoFees;

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
        (processorFees, daoFees) = scvUSD.fees(0);
    }

    function test_nominal(uint120 amountIn) external {
        vm.assume(amountIn > 100 ether);

        // Deposit for Stable rewards
        depositSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, false, true);

        // Deposit for governance rewards
        depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usr1, amountIn, true);

        skip(182 days);
        uint256 processableRewards = gUSD.getStreamableShares();

        uint256 processorRewards = (processableRewards * processorFees) / 100_000;
        uint256 daoRewards = (processableRewards * daoFees) / 100_000;
        uint256 stakerRewards = processableRewards - processorRewards - daoRewards;

        uint256 userBalanceLendAsset = lendAsset.balanceOf(usr1);

        gUSD.processStableRewards(processor);

        assertEq(processableRewards - processorRewards, llamaVault.balanceOf(address(splitter)), "Lend Asset amount is received by Splitter");
        assertEq(daoRewards, splitter.daoFeeForToken(llamaVault), "Dao fees incremented");
        assertEq(processorRewards, llamaVault.balanceOf(processor), "Processor received processor rewards");

        // Withdraw the fees
        IERC20[] memory tokensToClaim = new IERC20[](1);
        tokensToClaim[0] = AddrClassicERC20.TOKEN_CRVUSD;

        uint256 ownerBalanceLendAsset = lendAsset.balanceOf(owner);
        uint256 splitterBalanceLendAsset = lendAsset.balanceOf(address(splitter));

        vm.prank(feeTreasury);
        splitter.withdrawFees(tokensToClaim);

        assertEq(daoRewards, lendAsset.balanceOf(feeTreasury) - ownerBalanceLendAsset, "Processor received processor rewards");
        assertEq(daoRewards, splitterBalanceLendAsset - lendAsset.balanceOf(address(splitter)), "Splitter sent rewards");
        assertEq(splitter.daoFeeForToken(AddrClassicERC20.TOKEN_CRVUSD), 0, "Dao fee is reseted");
    }
}
