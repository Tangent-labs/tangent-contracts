// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {OracleCryptoSwap} from "src/USG/Oracles/CurveLP/OracleCryptoSwap.sol";
import {IPriceOracle} from "src/interfaces/internals/USG/IPriceOracle.sol";

/// forge script script/DeployOracleCryptoSwap.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployOracleCryptoSwap is Script {
    address constant TRICRV_LP = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
    // PROD_ADDRESSES.ORACLES.CHAINLINK.crvUSD
    IPriceOracle constant CRVUSD_ORACLE = IPriceOracle(0x63f1715e46D9Ce230f09a34c7D051Ec0f738Fe2B);

    function run() external returns (OracleCryptoSwap oracle) {
        vm.startBroadcast();
        oracle = new OracleCryptoSwap(TRICRV_LP, CRVUSD_ORACLE, "crvUSD_ETH_CRV/USD");
        vm.stopBroadcast();

        uint256 price = oracle.latestAnswer(false);
        console.log("crvUSD_frxUSD/USD oracle deployed at", address(oracle));
        console.log("price", price);
    }
}
