// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MarketInit, GlobalMarketInitParams} from "../../interfaces/internals/USG/IMarketCore.sol";
import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";
import {MarketExternalActions} from "./abstract/MarketExternalActions.sol";

/// @title BasicERC20Market
/// @author Tangent Finance
/// @notice Lending Market for a token that is not a staked position and doesn't have rewards to claim when held.
contract BasicERC20Market is MarketExternalActions {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
    }
}
