import "../../../contexts/ConvexMarketContext.sol";

contract ProcessGovRewards is ConvexMarketContext {
    ISplitterToken.Fees[] feePercentage;

    struct Fees {
        uint128 processorFeePercentage;
        uint128 daoFeePercentage;
    }

    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();

        (uint128 processorFeePercentageCrv, uint128 daoFeePercentageCrv) = gUSD.fees(0);
        (uint128 processorFeePercentageCvx, uint128 daoFeePercentageCvx) = gUSD.fees(1);
        feePercentage.push(ISplitterToken.Fees({processorFeePercentage: processorFeePercentageCrv, daoFeePercentage: daoFeePercentageCrv}));
        feePercentage.push(ISplitterToken.Fees({processorFeePercentage: processorFeePercentageCvx, daoFeePercentage: daoFeePercentageCvx}));
    }

    function test_process_governance_rewards() external {
        // PREPARE
        address processor = makeAddr("Processor");
        deal(address(lendAsset), processor, 100 ether);
        vm.startPrank(processor);

        uint256 deltaBalanceCrvSplitter = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(address(splitter));
        uint256 deltaBalanceCvxSplitter = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(address(splitter));

        uint256 deltaBalanceCrvProcessor = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(processor);
        uint256 deltaBalanceCvxProcessor = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(processor);

        // ACTIONS
        lendAsset.approve(address(splitter), 100 ether);
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true);
        skip(1 weeks);
        gUSD.processGovRewards();

        // VERIFY

        deltaBalanceCrvSplitter = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(address(splitter)) - deltaBalanceCrvSplitter;
        deltaBalanceCvxSplitter = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(address(splitter)) - deltaBalanceCvxSplitter;

        deltaBalanceCrvProcessor = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(processor) - deltaBalanceCrvProcessor;
        deltaBalanceCvxProcessor = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(processor) - deltaBalanceCvxProcessor;

        uint256 totalCrvProcessed = deltaBalanceCrvSplitter + deltaBalanceCrvProcessor;
        uint256 totalCvxProcessed = deltaBalanceCvxSplitter + deltaBalanceCvxProcessor;

        uint256 processorFeesCrv = (totalCrvProcessed * feePercentage[0].processorFeePercentage) / 100_000;
        uint256 processorFeesCvx = (totalCvxProcessed * feePercentage[1].processorFeePercentage) / 100_000;

        uint256 daoFeesCrv = (totalCrvProcessed * feePercentage[0].daoFeePercentage) / 100_000;
        uint256 daoFeesCvx = (totalCvxProcessed * feePercentage[1].daoFeePercentage) / 100_000;

        uint256 crvRewardsForStakers = totalCrvProcessed - processorFeesCrv - daoFeesCrv;
        uint256 cvxRewardsForStakers = totalCvxProcessed - processorFeesCvx - daoFeesCvx;

        // Verify processor received the right amount of rewards
        assertEq(processorFeesCrv, deltaBalanceCrvProcessor);
        assertEq(processorFeesCvx, deltaBalanceCvxProcessor);

        // Verify that the daoFees are stored in the daoFeeForToken mapping
        assertEq(daoFeesCrv, splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CRV)));
        assertEq(daoFeesCvx, splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CVX)));

        // Verify that the rewards for stakers are on the splitter contract.
        // It should be equal to the balance delta on the splitter minus the fees added for the DAO
        assertEq(crvRewardsForStakers, deltaBalanceCrvSplitter - splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CRV)));
        assertEq(cvxRewardsForStakers, deltaBalanceCvxSplitter - splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CVX)));

        // Splitter received more than 0 rewards
        assertGt(deltaBalanceCrvSplitter, 0);
        assertGt(deltaBalanceCvxSplitter, 0);
    }

    function test_process_governance_rewards_with_nothing_to_claim() external {
        // PREPARE
        address processor = makeAddr("Processor");
        deal(address(lendAsset), processor, 100 ether);
        vm.startPrank(processor);

        // ACTIONS
        lendAsset.approve(address(splitter), 100 ether);
        splitter.depositGUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true);
        skip(2 weeks);
        gUSD.processGovRewards();
        // Ensure that second process of reward is failing because all CRV rewards have been already processed
        vm.expectRevert(abi.encodeWithSelector(SplitterToken.NothingToProcess.selector));
        gUSD.processGovRewards();
    }
}
