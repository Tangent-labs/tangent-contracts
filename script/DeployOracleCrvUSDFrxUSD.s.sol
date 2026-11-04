// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {OracleDuoPoolStable} from "src/USG/Oracles/CurveLP/OracleDuoPoolStable.sol";
import {IPriceOracle} from "src/interfaces/internals/USG/IPriceOracle.sol";

/// forge script script/DeployOracleCrvUSDFrxUSD.s.sol --rpc-url mainnet --account <keystore> --broadcast --verify
contract DeployOracleCrvUSDFrxUSD is Script {
    address constant CRVUSD_FRXUSD_LP = 0x13e12BB0E6A2f1A3d6901a59a9d585e89A6243e1;
    // PROD_ADDRESSES.ORACLES.CHAINLINK.crvUSD
    IPriceOracle constant CRVUSD_ORACLE = IPriceOracle(0x63f1715e46D9Ce230f09a34c7D051Ec0f738Fe2B);
    // PROD_ADDRESSES.ORACLES.COIN_FROM_CURVE_LP.frxUSD
    IPriceOracle constant FRXUSD_ORACLE = IPriceOracle(0x8aa49a3ba86ED4C9fe8FA787934d2F7860509859);

    function run() external returns (OracleDuoPoolStable oracle) {
        vm.startBroadcast();
        oracle = new OracleDuoPoolStable(CRVUSD_FRXUSD_LP, FRXUSD_ORACLE, CRVUSD_ORACLE, "crvUSD_frxUSD/USD");
        vm.stopBroadcast();

        uint256 price = oracle.latestAnswer(false);
        require(price > 0.998 ether && price < 1.1 ether, "LP price off peg");
        console.log("crvUSD_frxUSD/USD oracle deployed at", address(oracle));
        console.log("price", price);
    }
}
