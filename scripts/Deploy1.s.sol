// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

import {Tan} from "../src/USG/Tokens/Tan.sol";

import "../src/USG/Market/Convex/ConvexCrvLPMarket.sol";
import "../src/USG/Market/Convex/ConvexFxnLPMarket.sol";
import "../src/USG/Market/MarketNoSociabilization.sol";

import "../src/USG/Tokens/USG.sol";
import "../src/USG/Tokens/WStable.sol";
import "../src/USG/Rewards/RewardAccumulator.sol";
import "../src/USG/Utilities/ControlTower.sol";
import "../src/USG/Utilities/MarketCreator.sol";
import "../src/USG/Utilities/ZappingProxy.sol";

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
