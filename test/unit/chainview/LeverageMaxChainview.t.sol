// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;
// import "../../contexts/MarketDeploymentContext.sol";

// import {LeverageMaxUI, TokenOracle} from "../../../src/chainview/USG/ui/LeverageMaxUI.cv.sol";

// contract LeverageMaxChainview is MarketDeploymentContext {
//     // LIST
//     function test_MaxLeverage_returns() public {
//         ICurveStableSwapNG[] memory lps = new ICurveStableSwapNG[](2);
//         lps[0] = lpDeploymentContext.USGLPs("USG-USDC");

//         TokenOracle[] memory tokenOracles = new TokenOracle[](2);
//         tokenOracles[0] = TokenOracle({token: AddrClassicERC20.USDC, oracle: address(oracles[AddrClassicERC20.USDC])});

//         try new LeverageMaxUI(lps, tokenOracles, usg, USGOracle, 20e16) {} catch (bytes memory reason) {
//             abi.decode(removeFirst4Bytes(reason), (uint256));
//         }
//     }
// }
