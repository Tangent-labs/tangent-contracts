// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract IRCalculatorAdminFunctions is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
        vm.startPrank(owner);
    }

    function test_setTgUSDOracle_success() external {
        irCalculator.setTgUSDOracle(IAggregatorStablePriceV3(usr2));
        assertEq(usr2, address(irCalculator.tgUSDOracle()));
    }

    function test_updateIRParams_success() external {
        IRCheckpoint memory irCheck = irCalculator.getIRCheckpoint(address(market));
        assertEq(irCheck.ir, 0);

        irCalculator.updateIRParams(address(market), IRParams(false, 5_000, 100_000, 0, 0, 0, 0, 0, 0));

        irCheck = irCalculator.getIRCheckpoint(address(market));

        assertEq(irCheck.ir, 5e16);
    }

    function test_updateIRParams_fails_as_a1_bigger_than_20() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.A1TooBig.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 100_000, pMin: 0, pInf: 0, pMax: 0, a1: 20_001, a2: 0, k: 0}));
    }

    function test_updateIRParams_fails_as_a2_bigger_than_20() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.A2TooBig.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 100_000, pMin: 0, pInf: 0, pMax: 0, a1: 0, a2: 20_001, k: 0}));
    }

    function test_updateIRParams_fails_as_k_bigger_than_20000() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.KTooBig.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 100_000, pMin: 0, pInf: 0, pMax: 0, a1: 0, a2: 0, k: 20_001}));
    }

    function test_updateIRParams_fails_as_rMax_bigger_than_400() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.RMaxTooBig.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 400_001, pMin: 0, pInf: 0, pMax: 0, a1: 0, a2: 0, k: 0}));
    }

    function test_updateIRParams_fails_as_rMinTooBig() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.RMinBiggerThanRMax.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 1, rMax: 0, pMin: 0, pInf: 0, pMax: 0, a1: 0, a2: 0, k: 0}));
    }

    function test_updateIRParams_fails_as_pMinBiggerThanPInf() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.PMinBiggerThanPInf.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 0, pMin: 1, pInf: 0, pMax: 0, a1: 0, a2: 0, k: 0}));
    }

    function test_updateIRParams_fails_as_pInfBiggerThanPMax() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.PInfBiggerThanPMax.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 0, pMin: 1, pInf: 3, pMax: 2, a1: 0, a2: 0, k: 0}));
    }

    function test_updateIRParams_fails_as_pMaxBiggerThanOneDollar() external {
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.PMaxBiggerThanOneDollar.selector));
        irCalculator.updateIRParams(address(market), IRParams({isHEC: false, rMin: 0, rMax: 0, pMin: 1, pInf: 2, pMax: 1_000_001, a1: 0, a2: 0, k: 0}));
    }
}
