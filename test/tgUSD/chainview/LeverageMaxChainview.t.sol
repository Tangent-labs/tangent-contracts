// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/MarketDeploymentContext.sol";

import {LeverageMaxUI, TokenOracle} from "../../../src/chainview/tgUSD/ui/LeverageMaxUI.cv.sol";

contract LeverageMaxChainview is MarketDeploymentContext {
    // LIST
    function test_MaxLeverage_returns() public {
        ICurveStableSwapNG[] memory lps = new ICurveStableSwapNG[](2);
        lps[0] = lpDeploymentContext.tgUSDLPs("tgUSD-USDC");
        lps[1] = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD");

        TokenOracle[] memory tokenOracles = new TokenOracle[](2);
        tokenOracles[0] = TokenOracle({token: AddrClassicERC20.USDC, oracle: address(oracles[AddrClassicERC20.USDC])});
        tokenOracles[1] = TokenOracle({token: wfrxUSD, oracle: address(oracles[AddrClassicERC20.frxUSD])});

        try new LeverageMaxUI(lps, tokenOracles, tgUSD, tgUSDOracle, 20e16) {} catch (bytes memory reason) {
            abi.decode(removeFirst4Bytes(reason), (uint256));
        }
    }
}
