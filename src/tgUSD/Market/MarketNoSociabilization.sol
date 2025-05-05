// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MarketInit, GlobalMarketInitParams} from "../../interfaces/internals/tgUSD/IMarketCore.sol";
import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";
import {MarketExternalActions} from "./abstract/MarketExternalActions.sol";

/// @notice
contract MarketNoSociabilization is MarketExternalActions {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
    }
}
