// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract GetOraclePTMarketPrice is MarketDeploymentContext {
    IERC20Metadata[] pendlePTs;

    function test_price_sUSD_PT_post_expi() external {
        uint256 sUSDePrice = oracles[AddrERC4626.sUSDe].latestAnswer(true);
        uint256 oneUSDeInsUSDe = AddrERC4626.sUSDe.convertToShares(1e18);
        uint256 oraclePrice = oracles[AddrPTPendle.sUSDe_05_02_26].latestAnswer(true);

        assertEq(oraclePrice, (sUSDePrice * oneUSDeInsUSDe) / 1e18);

        console.log("sUSDe POST expi =>", oraclePrice);
    }

    function test_price_USD_PT_post_expi() external {
        uint256 oraclePrice = oracles[AddrPTPendle.USDe_27_11_25].latestAnswer(true);
        uint256 USDePrice = oracles[AddrClassicERC20.USDe].latestAnswer(true);

        assertEq(oraclePrice, USDePrice);
        console.log("USDe POST expi =>", oraclePrice);
    }
    function test_price_sUSD_PT_pre_expi() external {
        OraclePendlePT ptOracle = new OraclePendlePT(IPendleMarketV3(0x8dAe8ECe668cf80d348873F23D456448E8694883), oracles[AddrERC4626.sUSDS], 400, 18, "PT sUSDS / USD");
        uint256 oraclePrice = ptOracle.latestAnswer(true);
        console.log("sUSDS pre expi =>", oraclePrice);
    }

    function test_price_USD_PT_pre_expi() external {
        OraclePendlePT ptOracle = new OraclePendlePT(IPendleMarketV3(0xA3336f04f7AfbF26714331e395054F33B77C9b8D), oracles[AddrClassicERC20.USDS], 400, 18, "PT USDS / USD");
        uint256 oraclePrice = ptOracle.latestAnswer(true);
        console.log("USDS pre expi =>", oraclePrice);
    }

    function test_price_PT_BTC() external {
        OraclePendlePT ptOracle = new OraclePendlePT(AddrMarketPendle.mHyperBTC_30_04_26, oracles[AddrClassicERC20.WBTC], 400, 28, "PT mHyper / USD");
        uint256 oraclePrice = ptOracle.latestAnswer(true);
        console.log("mHyperBTC pre expi =>", oraclePrice);
    }

    // function test_price_USD_PT_post_expi() external {
    //     uint256 oraclePrice = oracles[AddrPTPendle.sUSDS_05_02_26].latestAnswer(true);

    //     uint256 sUSDSPrice = oracles[AddrERC4626.sUSDS].latestAnswer(true);
    //     uint256 oneUSDSInsUSDS = AddrERC4626.sUSDS.convertToShares(1e18);

    //     assertEq(oraclePrice, oracleValueBeforeSwap);
    // }

    // function test_determine_PT_price() external {
    //     for (uint256 i = 0; i < pendlePTs.length; i++) {
    //         IERC20Metadata pt = pendlePTs[i];
    //         uint256 oracleValue = oracles[pt].latestAnswer(true);
    //     }

    //     skip(365 days);

    //     for (uint256 i = 0; i < pendlePTs.length; i++) {
    //         IERC20Metadata pt = pendlePTs[i];
    //         uint256 oracleValueBeforeSwap = oracles[pt].latestAnswer(true);

    //         (, IPriceOracle underlyingOracle, , , , ) = OraclePendlePT(address(oracles[pt])).params();

    //         assertEq(underlyingOracle.latestAnswer(true), oracleValueBeforeSwap);
    //     }
    // }
}
