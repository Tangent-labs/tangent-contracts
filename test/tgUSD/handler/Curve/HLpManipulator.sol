// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../Base/HandlerBase.sol";
import "../../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";

contract HLpManipulator is HandlerBase {
    constructor(address _sender, MarketExternalActions _market) HandlerBase(_sender, _market) {}
    function dumpCrvPool(ICurveStableSwapNG curvePool, uint256 i, uint256 j, uint256 amount) external {
        IERC20 coinToDump = IERC20(curvePool.coins(i));
        deal(address(coinToDump), sender, amount);

        vm.startPrank(sender);
        coinToDump.approve(address(curvePool), MAX_UINT);
        curvePool.exchange(int128(int256(i)), int128(int256(j)), amount, 0);
        vm.stopPrank();
    }
}
