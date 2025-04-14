// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../../../src/tgUSD/Utilities/IRCalculator.sol";
import "../../../utils/IRCalculationFFI.sol";
contract DebtIndexComputation is ConvexCurveContext {
    IRCalculationFFI irFFI = new IRCalculationFFI();

    uint256 oldIndex;
    uint256 ir;
    uint256 timeDelta;

    function test_fuzzing_debtIndex_computation(uint256 oldIndex_, uint256 ir_, uint256 timeDelta_) external {
        oldIndex_ = bound(oldIndex_, 1e27, 10 * 1e27);
        ir_ = bound(ir_, 0, 10 ** 19); // 0% => 1 000 %
        timeDelta_ = bound(ir_, 0, 20 * 365 days); //

        uint256 expected = irFFI.getIndexFFI(oldIndex_, ir_, timeDelta_);
        uint256 calculated = irCalculator.simulateNewDebtIndex(oldIndex_, ir_, timeDelta_);

        if (expected <= 10_000) {
            assertApproxEqAbs(expected, calculated, 1); // 1 wei delta
        } else {
            assertApproxEqRel(expected, calculated, 1 * 1e5); //0.00000000001% delta
        }
    }
}
