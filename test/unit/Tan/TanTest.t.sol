// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract TanTest is MarketDeploymentContext {
    uint256 amountToBurn = 1_000_000 ether;
    function test_burn_TAN() external {
        verifyBurnERC20(tan, amountToBurn);
        verifyLostERC20(tan, owner, amountToBurn);

        vm.prank(owner);
        tan.burn(amountToBurn);
        assertERC20Tracking();
    }

    function test_burn__fails_with_0() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(TAN.ZeroAmount.selector));
        tan.burn(0);
    }
}
