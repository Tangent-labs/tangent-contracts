// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../utils/IRCalculationFFI.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract CheckpointMulti is MarketDeploymentContext {
    address[] public markets;
    uint256[] public irs;
    uint256[] public indexes;
    uint256[] public expectedIndexes;
    HLPManipulator public lpManipulator;

    IRCalculationFFI public irCalculationFFI;

    uint256 depositedAmount = 10_000 ether;
    uint256 borrowedAmount = 7_000 ether;
    uint256 USGPrice;
    uint256 timestamp;
    function setUp() public {
        // We deploy few contracts. LEC contracts start to accumulate IR since now
        markets.push(address(deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true)));
        markets.push(address(deployConvexCurveLPMarket(AddrCurveStableLP.sUSDS_USDT, false)));
        markets.push(address(deployBasicERC20Market(AddrPTPendle.sUSDe_31_07_25)));
        markets.push(address(deployBasicERC20Market(AddrPTPendle.eUSDe_29_05_25)));
        markets.push(address(deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD)));

        lpManipulator = new HLPManipulator(owner);
        irCalculationFFI = new IRCalculationFFI();

        // Depegs of the LPs
        lpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 1, 0, 350_000 ether);
        lpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-wcrvUSD"), 1, 0, 350_000 ether);

        skip(1 weeks);
        vm.startPrank(usr4);
        USGPrice = USGOracle.price_w();
        for (uint256 i; i < markets.length; i++) {
            address market = markets[i];
            IERC20 collat = ICollateral(market).collatToken();

            deal(address(collat), usr4, depositedAmount);
            collat.approve(market, MAX_UINT);

            MarketExternalActions(market).depositAndBorrow(depositedAmount, borrowedAmount);
            indexes.push(irCalculator.debtIndexes(market));

            IRCheckpoint memory irCheckpoint = irCalculator.getIRCheckpoint(market);

            irs.push(irCheckpoint.ir);
        }
        timestamp = block.timestamp;

        skip(1 weeks);
    }

    function test_checkpoint_IR_multi() external {
        for (uint256 i; i < markets.length; i++) {
            expectedIndexes.push(irCalculationFFI.getIndexFFI(indexes[i], irs[i], timestamp));
        }

        irCalculator.checkpointIRMulti(markets);

        uint256 totalNewIR;

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i];
            uint256 newIndex = irCalculator.debtIndexes(market);
            totalNewIR += ((newIndex - indexes[i]) * IDebtIR(market).totalDebtShares()) / RAY;
            assertApproxEqRel(newIndex, expectedIndexes[i], 1e5);
        }

        assertEq(irCalculator.mintableInterests(), totalNewIR);

        verifyMintERC20(usg, totalNewIR, "IR minted");
        verifyReceiveERC20(usg, controlTower.feeTreasury(), totalNewIR, "Interests received by Fee Treasury");
        irCalculator.mintIR();
        assertERC20Tracking();

        assertEq(irCalculator.mintableInterests(), 0);
    }

    function test_checkpoint_IR_multi_when_some_are_already_checkpointed_before() external {
        irCalculator.checkpointIR(markets[0]);
        irCalculator.checkpointIR(markets[3]);
        for (uint256 i; i < markets.length; i++) {
            expectedIndexes.push(irCalculationFFI.getIndexFFI(indexes[i], irs[i], timestamp));
        }

        irCalculator.checkpointIRMulti(markets);

        uint256 totalNewIR;

        for (uint256 i; i < markets.length; i++) {
            address market = markets[i];

            uint256 newIndex = irCalculator.debtIndexes(market);

            uint256 newInterests = ((newIndex - indexes[i]) * IDebtIR(market).totalDebtShares()) / RAY;

            totalNewIR += newInterests;

            assertApproxEqRel(newIndex, expectedIndexes[i], 1e5);
        }

        assertEq(irCalculator.mintableInterests(), totalNewIR);

        verifyMintERC20(usg, totalNewIR, "IR minted");
        verifyReceiveERC20(usg, controlTower.feeTreasury(), totalNewIR, "Interests received by Fee Treasury");
        irCalculator.mintIR();
        assertERC20Tracking();

        assertEq(irCalculator.mintableInterests(), 0);
    }
}
