import "../../../contexts/ConvexMarketContext.sol";

contract ProcessStableConvex is ConvexMarketContext {
    uint256 processorFees;
    uint256 daoFees;

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
        (processorFees, daoFees) = scvUSD.fees(0);
    }

    function test_nominal() external {
        uint256 amount = 100 ether;
        address user = makeAddr("USER");
        address processor = makeAddr("PROCESSOR");
        deal(address(lendAsset), user, amount * 1000);
        vm.startPrank(user);
        AddrClassicERC20.TOKEN_CRVUSD.approve(address(splitter), type(uint256).max);

        // Deposit for stable rewards
        splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, false, true);

        // Deposit for governance rewards
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, true);

        skip(100 days);
        uint256 processableRewards = llamaVault.convertToAssets(gUSD.getStreamableShares());

        uint256 processorRewards = (processableRewards * processorFees) / 100_000;
        uint256 daoRewards = (processableRewards * daoFees) / 100_000;
        uint256 stakerRewards = processableRewards - processorRewards - daoRewards;

        uint256 userBalanceLendAsset = lendAsset.balanceOf(user);
        vm.stopPrank();
        vm.prank(processor);
        gUSD.processStableRewards();

        assertEq(stakerRewards + daoRewards, lendAsset.balanceOf(address(splitter)), "Lend Asset amount is received by Splitter");
        assertEq(daoRewards, splitter.daoFeeForToken(lendAsset), "Dao fees incremented");
        assertEq(processorRewards, lendAsset.balanceOf(processor), "Processor received processor rewards");

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
