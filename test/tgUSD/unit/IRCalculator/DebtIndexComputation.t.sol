// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../../../src/tgUSD/Utilities/IRCalculator.sol";
import "../../../utils/IRCalculationFFI.sol";
contract DebtIndexComputation is MarketDeploymentContext {
    IRCalculationFFI irFFI = new IRCalculationFFI();

    function test_debtIndex_computation_fuzzing(uint256 oldIndex_, uint256 ir_, uint256 timestamp) external {
        oldIndex_ = bound(oldIndex_, 1e27, 1e29); // 1 => 100
        ir_ = bound(ir_, 0, 1e19); // 0% => 1 000 %
        timestamp = bound(timestamp, block.timestamp - 20 * 365 days, block.timestamp); // 0 => 20 years

        uint256 expected = irFFI.getIndexFFI(oldIndex_, ir_, timestamp);
        uint256 calculated = irCalculator.simulateNewDebtIndex(oldIndex_, IRCheckpoint({ir: uint216(ir_), timestamp: uint40(timestamp)}));

        if (expected <= 10_000) {
            assertApproxEqAbs(expected, calculated, 1); // 1 wei delta
        } else {
            assertApproxEqRel(expected, calculated, 1 * 1e5); //0.00000000001% delta
        }
    }
}
