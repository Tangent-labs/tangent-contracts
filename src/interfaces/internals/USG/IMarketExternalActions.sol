// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20, TokenAmount, ZapStruct} from "../ICommonStruct.sol";

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IMigratoor, MigrateStruct} from "./IMigratoor.sol";
import {IControlTower} from "./IControlTower.sol";
interface IMarketExternalActions {
    function deposit(address _for, uint256 lpDeposited) external;

    function borrow(address receiver, uint256 USGToBorrow) external;

    function depositAndBorrow(uint256 lpDeposited, uint256 debtBorrow) external;

    function repay(address account, uint256 USGToRepay) external;

    function liquidate(address account, uint256 USGToRepay, uint256 minUSGOut, ZapStruct calldata zap) external;

    function leverage(uint256 collatToDeposit, uint256 USGToFlashMint, uint256 minCollatAmountOut, ZapStruct calldata zap) external;

    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external returns (TokenAmount[] memory);

    function migrateFrom(
        IControlTower _controlTower,
        address account,
        uint256 collateralToRemove,
        uint256 debtToRemove,
        uint256 debtToRepay,
        address collatReceiver
    ) external returns (uint256);

    function migrateTo(IControlTower _controlTower, address account, uint256 collatToAdd, uint256 debtToAdd) external returns (uint256);

    function reeantrancyOn(IControlTower _controlTower) external returns (IERC20);

    function reeantrancyOff(IControlTower _controlTower) external;
}
