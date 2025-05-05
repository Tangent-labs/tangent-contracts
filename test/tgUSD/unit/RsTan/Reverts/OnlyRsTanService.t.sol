// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Curve/HLpManipulator.sol";

contract OnlyRsTanService is MarketDeploymentContext {
    uint208 amount = 1 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amount);
        tan.approve(address(rsTanService), 2 * amount);
        rsTanService.createLock(amount, true);
        rsTanService.createLock(amount, false);
        vm.stopPrank();
    }

    function test_mintForCreate_as_not_service() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTanERC721.CallerNotService.selector));
        rsTanERC721.mintForCreate(usr1);
    }

    function test_mintForSplit_as_not_service() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTanERC721.CallerNotService.selector));
        rsTanERC721.mintForSplit(usr1, 2);
    }

    function test_burnForMerge_as_not_service() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(RsTanERC721.CallerNotService.selector));
        rsTanERC721.burnForMerge(1, 2, usr1);
    }

    function test_burnForUnlock_as_not_service() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTanERC721.CallerNotService.selector));
        rsTanERC721.burnForUnlock(2, usr1);
    }

    function test_burKickPosition_as_not_service() external {
        vm.startPrank(usr2);
        vm.expectRevert(abi.encodeWithSelector(RsTanERC721.CallerNotService.selector));
        rsTanERC721.burKickPosition(2);
    }
}
