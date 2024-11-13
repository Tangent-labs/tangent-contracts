// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.22;

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// import {ConvexCrvLPMarket, IERC20, ICvxRewardToken, ItgUSD} from "./Convex/ConvexCrvLPMarket.sol";

// import "forge-std/console.sol";
// /// @notice OFT is an ERC-20 token that extends the OFTCore contract.
// contract MarketFactory is Ownable {
//     ItgUSD public tgUSD;
//     constructor(address _owner, ItgUSD _tgUSD) Ownable(_owner) {
//         tgUSD = _tgUSD;
//     }

//     function createConvexMarket(
//         ConvexCrvLPMarket.MarketInit memory _marketInit,
//         IERC20[] memory _rewardTokens,
//         ICvxRewardToken _cvxRewardToken,
//         uint256 _pid
//     ) external returns (ConvexCrvLPMarket) {
//         ConvexCrvLPMarket cvxMarket = new ConvexCrvLPMarket(_marketInit, _rewardTokens, _cvxRewardToken, _pid);
//         return cvxMarket;
//     }
// }
