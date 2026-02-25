// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {OracleBase} from "../OracleBase.sol";

struct OracleERC4626Struct {
    IERC4626 erc4626;
    IPriceOracle underlyingOracle;
    uint48 assetDecimals;
    uint48 shareDecimals;
}
/// @title OracleERC4626
/// @author Tangent Finance
/// @notice This contract provides price oracle functionality for an ERC4626.
contract OracleERC4626 is OracleBase {
    OracleERC4626Struct public params;
    constructor(IERC4626 _erc4626, IPriceOracle _underlyingOracle, string memory _oracleName) OracleBase(_oracleName) {
        params = OracleERC4626Struct({
            erc4626: _erc4626,
            underlyingOracle: _underlyingOracle,
            assetDecimals: IERC20Metadata(_erc4626.asset()).decimals(),
            shareDecimals: _erc4626.decimals()
        });
    }

    /**
     * @notice Returns the price of the ERC4626 configured
     * @return The price of the token from the pool.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleERC4626Struct memory _params = params;
        // Find the price of the underlying asset in $
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params.erc4626, _params.assetDecimals, _params.shareDecimals);
    }

    /**
     * @notice Returns the price of the ERC4626 configured
     * @return The price of the token from the pool.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleERC4626Struct memory _params = params;
        // Find the price of the underlying asset in $ and update the lastGoodValue if needed
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params.erc4626, _params.assetDecimals, _params.shareDecimals);
    }

    function _computePrice(uint256 underlyingPrice, IERC4626 savingAccount, uint256 assetDecimals, uint256 shareDecimals) internal view returns (uint256) {
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return (savingAccount.convertToAssets(10 ** shareDecimals) * underlyingPrice) / 10 ** (assetDecimals);
    }
}
