// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../utils/IRCalculationFFI.sol";

///  A "fixed rate" market is an LEC market configured with rMin == rMax:
///         `_computeIR` then returns the same rate whatever the USG price.
///
///         `_computeIR` has three exits, and the params below pick the cheap one:
///           A: price <= pMin * 1e12  -> rMax * 1e13                        (~8k gas)
///           B: price >= pMax * 1e12  -> rMin * 1e13, or 0 when isHEC       (~8k gas)
///           C: in between            -> full ABDK sigmoid + exp/log/exp_2  (~29k gas)
///
///         With pMin = 0 / pInf = pMax = 1, every price above 0.000001$ takes exit B,
///         so the sigmoid is never evaluated. `_computeIR` runs on every checkpointIR,
///         i.e. on every deposit / borrow / repay / liquidation, so the ~21k saved is
///         paid back on each user interaction.
///
///         a1 / a2 / k are left at 0: the curve they parametrise is unreachable here.
contract FixedRateMarket is MarketDeploymentContext {
    uint216 constant FIXED_IR = 10 * 1e16; // 10% <=> rMin = rMax = 10_000

    BasicERC20Market public market;
    IRCalculationFFI irFFI = new IRCalculationFFI();

    ///  The cheapest fixed-rate configuration: always exits `_computeIR` on branch B.
    function fixedParams() internal pure returns (IRParams memory) {
        return
            IRParams({
                isHEC: false,
                rMin: 10_000,
                rMax: 10_000,
                pMin: 0,
                pInf: 1,
                pMax: 1,
                a1: 0,
                a2: 0,
                k: 0
            });
    }

    ///  Same fixed rate, but reached through the expensive sigmoid branch.
    ///         Kept only to prove the rate is flat on that path too.
    function fixedParamsOnSigmoidBranch()
        internal
        pure
        returns (IRParams memory)
    {
        return
            IRParams({
                isHEC: false,
                rMin: 10_000,
                rMax: 10_000,
                pMin: 980_000,
                pInf: 990_000,
                pMax: 995_000,
                a1: 2_500,
                a2: 3_500,
                k: 250
            });
    }

    function setUp() public {
        market = deployBasicERC20Market(AddrCurveStableLP.sUSDS_USDT);
        vm.prank(owner);
        irCalculator.updateIRParams(address(market), fixedParams());
    }

    function _setUSGPrice(uint256 price) internal {
        vm.mockCall(
            address(USGOracle),
            abi.encodeWithSelector(IAggregatorStablePriceV3.price_w.selector),
            abi.encode(price)
        );
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    RATE VS USG PRICE
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// Sweeps USG from 0.90$ to 1.10$ by 1 cent: the rate never moves.
    function test_fixed_rate_is_flat_over_price_sweep() external view {
        IRParams memory params = fixedParams();
        for (
            uint256 price = 0.9 ether;
            price <= 1.1 ether;
            price += 0.01 ether
        ) {
            assertEq(
                irCalculator.simulateIR(price, params),
                FIXED_IR,
                "IR must not depend on the USG price"
            );
        }
    }

    /// Over the whole price domain, so the unreachable-in-practice branches A and C are covered too.
    function test_fixed_rate_is_flat_fuzzed(uint256 USGPrice) external view {
        USGPrice = bound(USGPrice, 0, 2 ether);
        assertEq(irCalculator.simulateIR(USGPrice, fixedParams()), FIXED_IR);
    }

    /// The expensive sigmoid config is flat as well - it just costs ~21k more gas to say so.
    function test_fixed_rate_is_flat_on_sigmoid_branch_too(
        uint256 USGPrice
    ) external view {
        USGPrice = bound(USGPrice, 0, 2 ether);
        assertEq(
            irCalculator.simulateIR(USGPrice, fixedParamsOnSigmoidBranch()),
            FIXED_IR
        );
    }

    /// The on-chain checkpointed rate of the market stays at 10% while USG depegs and repegs.
    function test_market_ir_stable_while_USG_depegs() external {
        uint256[6] memory prices = [
            uint256(1.02 ether),
            1 ether,
            0.995 ether,
            0.99 ether,
            0.97 ether,
            1 ether
        ];

        for (uint256 i; i < prices.length; i++) {
            _setUSGPrice(prices[i]);
            skip(1 days);
            irCalculator.checkpointIR(address(market));
            assertEq(
                irCalculator.getIRCheckpoint(address(market)).ir,
                FIXED_IR,
                "Checkpointed IR drifted with the USG price"
            );
        }
    }

    /// Over a year of moving prices, the debt index compounds exactly at the fixed rate: exp(0.1) - 1 ~ 10.517%.
    function test_debt_index_compounds_at_fixed_rate_over_a_year() external {
        _setUSGPrice(1 ether);
        irCalculator.checkpointIR(address(market));
        uint256 startIndex = irCalculator.debtIndexes(address(market));

        // 12 monthly checkpoints, price wandering on each one
        uint256[12] memory prices = [
            uint256(1.01 ether),
            0.999 ether,
            0.992 ether,
            0.985 ether,
            0.96 ether,
            0.9 ether,
            0.98 ether,
            0.994 ether,
            1 ether,
            1.005 ether,
            0.97 ether,
            1 ether
        ];
        for (uint256 i; i < prices.length; i++) {
            _setUSGPrice(prices[i]);
            skip(365 days / 12);
            irCalculator.checkpointIR(address(market));
        }

        // exp(0.1) = 1.105170918...
        assertApproxEqRel(
            (irCalculator.debtIndexes(address(market)) * 1e18) / startIndex,
            1105170918075647624,
            1e12,
            "Index should compound at exactly 10%/year"
        );
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        GAS / TRAPS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// Guards the whole point of these params: a near-peg price must not reach the sigmoid.
    ///         Threshold sits between the two measured branches (~10.4k vs ~31.3k unoptimized,
    ///         call overhead included), so it fails loudly if the config drifts back to branch C.
    function test_fixed_rate_config_skips_the_sigmoid_branch() external view {
        uint256 gasBefore = gasleft();
        irCalculator.simulateIR(0.99 ether, fixedParams());
        uint256 cheap = gasBefore - gasleft();

        gasBefore = gasleft();
        irCalculator.simulateIR(0.99 ether, fixedParamsOnSigmoidBranch());
        uint256 expensive = gasBefore - gasleft();

        assertLt(
            cheap,
            15_000,
            "Fixed rate params should exit _computeIR early"
        );
        assertLt(
            cheap * 2,
            expensive,
            "Early exit should be far cheaper than the sigmoid path"
        );
    }

    /// A HEC market cannot be fixed rate: on branch B `_returnMinIR` forces the IR to 0,
    ///         and with these params every realistic price takes branch B.
    function test_HEC_market_cannot_be_fixed_rate() external view {
        IRParams memory params = fixedParams();
        params.isHEC = true;

        assertEq(
            irCalculator.simulateIR(0.99 ether, params),
            0,
            "A HEC market collapses to 0% on branch B"
        );
        assertEq(
            irCalculator.simulateIR(1.05 ether, params),
            0,
            "A HEC market collapses to 0% on branch B"
        );
    }
}
