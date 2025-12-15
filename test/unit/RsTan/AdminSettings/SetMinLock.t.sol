// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract SetMinLock is MarketDeploymentContext {
    function test_setMinLock() external {
        vm.startPrank(owner);
        vsTan.setMinLock(1212 ether);
        assertEq(1212 ether, vsTan.minLock());
    }

    function test_setMinLock_fails_onlyOwner() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        vsTan.setMinLock(1212 ether);
    }
}
