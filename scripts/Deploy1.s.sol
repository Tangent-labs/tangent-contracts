// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

import {Tan} from "../src/tgUSD/Tokens/Tan.sol";

import "../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";
import "../src/tgUSD/Market/MarketNoSociabilization.sol";

import "../src/tgUSD/Tokens/TgUSD.sol";
import "../src/tgUSD/Tokens/WStable.sol";
import "../src/tgUSD/Rewards/RewardAccumulator.sol";
import "../src/tgUSD/Utilities/ControlTower.sol";
import "../src/tgUSD/Utilities/MarketCreator.sol";
import "../src/tgUSD/Utilities/ZappingProxy.sol";

contract Deploy1 is Script {
    address convexCrvLPMarketImplem;
    address convexFxnLPMarketImplem;
    address marketNoSociabilizationImplem;

    ControlTower controlTower;

    address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address feeTreasury = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 pk;
    function setUp() public {
        pk = vm.envUint("PRIVATE_KEY");

        // deal(address(tan), owner, 12121212);
    }

    function run() public {
        vm.startBroadcast(pk);
        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketNoSociabilizationImplem = address(new MarketNoSociabilization());

        controlTower = new ControlTower(owner, feeTreasury);

        vm.stopBroadcast();
    }
}
