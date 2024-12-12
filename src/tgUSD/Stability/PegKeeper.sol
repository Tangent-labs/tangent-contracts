// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.22;

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
// import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

// import "forge-std/console.sol";

// contract ControlTower is Ownable, IControlTower {
//     uint256 public lastChangeTimestamp;
//     uint256 public debt;
//     uint256 public delay;

//     ICurvePool public immutable pool;
//     uint256 public immutable tgUSDIndex;

//     uint256 constant ONE_ETH;

//     error NotIRProducer(address irProducer);

//     constructor(address _owner, ICurvePool _pool) Ownable(_owner) {
//         pool = _pool;
//     }

//     function rebalance(address receiver) external view returns (uint256) {
//         uint256 tgUSDBalance = pool.balances(tgUSDIndex);
//         uint256 stableBalance = pool.balances(1 - tgUSDIndex) * 10 ** 12;

//         uint256 profit = _calcProfit();

//         if(stableBalance> tgUSDBalance){

//         }
//         else {
            
//         }
//     }

//     function _calcProfit() internal pure returns (uint256) {
//         return _profit(pool.get_virtual_price(), pool.balanceOf(address(this)), debt);
//     }

//     function _profit(uint256 virtualPrice, uint256 lpBalance, uint256 debt) internal pure returns (uint256) {
//         uint256 lpDebt = (debt * ONE_ETH) / virtualPrice;
//         if (lpBalance <= lpDebt) {
//             return 0;
//         } else {
//             return lpBalance - lpDebt;
//         }
//     }
// }
