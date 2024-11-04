// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";

library AddrCurveStableLP {
    ICurveStableSwapNG constant CRVUSD_USDC = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
}
