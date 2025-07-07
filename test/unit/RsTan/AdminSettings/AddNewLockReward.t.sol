// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract AddNewLockReward is MarketDeploymentContext {
    function test_addNewLockReward() external {
        vm.startPrank(owner);
        skip(7 days);
        vsTan.addNewReward(AddrClassicERC20.CRV);

        assertEq(address(usg), address(vsTan.rewardTokens(0)));
        assertEq(address(AddrClassicERC20.CRV), address(vsTan.rewardTokens(1)));

        assertEq(vsTan.getRewardData(usg).lastUpdateTime, block.timestamp - 7 days);
        assertEq(vsTan.getRewardData(AddrClassicERC20.CRV).lastUpdateTime, block.timestamp);
    }

    function test_addNewLockReward_fails_on_already_added_reward() external {
        vm.startPrank(owner);
        skip(7 days);

        vm.expectRevert(abi.encodeWithSelector(VsTan.RewardAlreadyAdded.selector, address(usg)));
        vsTan.addNewReward(usg);
    }
}
