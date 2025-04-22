// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../../src/interfaces/externals/Curve/ICurveTriCryptoSwap.sol";

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

contract HLpManipulator is Test {
    using SafeERC20 for IERC20;
    address public sender;
    constructor(address _sender) {
        sender = _sender;
    }

    function setMsgSender(address _sender) external {
        sender = _sender;
    }

    function dumpCrvPool(ICurveStableSwapNG curvePool, uint256 i, uint256 j, uint256 amount) external {
        IERC20 coinToDump = IERC20(curvePool.coins(i));
        deal(address(coinToDump), sender, amount);

        vm.startPrank(sender);
        coinToDump.forceApprove(address(curvePool), amount);
        curvePool.exchange(int128(int256(i)), int128(int256(j)), amount, 0);
        vm.stopPrank();
    }

    function dumTriCryptoSwapPool(ICurveTriCryptoSwap curvePool, uint256 i, uint256 j, uint256 amount) external {
        IERC20 coinToDump = IERC20(curvePool.coins(i));
        deal(address(coinToDump), sender, amount);

        vm.startPrank(sender);
        coinToDump.forceApprove(address(curvePool), amount);

        curvePool.exchange(i, j, amount, 0);
        vm.stopPrank();
    }
}
