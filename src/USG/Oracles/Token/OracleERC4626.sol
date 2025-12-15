// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {OracleBase} from "../OracleBase.sol";

struct OracleERC4626Struct {
    IERC4626 erc4626;
    IPriceOracle underlyingOracle;
    uint96 underlyingOracleDecimals;
}
/// @title OracleERC4626
/// @author Tangent Finance
/// @notice This contract provides price oracle functionality for an ERC4626.
contract OracleERC4626 is OracleBase {
    OracleERC4626Struct public params;
    constructor(IERC4626 _erc4626, IPriceOracle _underlyingOracle, string memory _oracleName) OracleBase(_oracleName) {
        params = OracleERC4626Struct({erc4626: _erc4626, underlyingOracle: _underlyingOracle, underlyingOracleDecimals: _underlyingOracle.decimals()});
    }

    /**
     * @notice Returns the price of the ERC4626 configured
     * @dev    Only works for 18 decimals asset.
     * @return The price of the token from the pool.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleERC4626Struct memory _params = params;
        // Find the price of the underlying asset in $
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return _computePrice(_params.underlyingOracle.latestAnswer(isNoFailMode), _params.erc4626);
    }

    /**
     * @notice Returns the price of the ERC4626 configured
     * @dev    Only works for 18 decimals asset.
     * @return The price of the token from the pool.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleERC4626Struct memory _params = params;
        // Find the price of the underlying asset in $ and update the lastGoodValue if needed
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return _computePrice(_params.underlyingOracle.latestAnswerUpdate(isNoFailMode), _params.erc4626);
    }

    function _computePrice(uint256 underlyingPrice, IERC4626 savingAccount) internal view returns (uint256) {
        // Find the ratio shares/assets, multiplied by the underlying price gives us the price of 1 share.
        return (savingAccount.convertToAssets(1e18) * underlyingPrice) / 1e18;
    }
}
