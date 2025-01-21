// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../../../src/libs/Resources/ResourcesConvex.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/libs/Resources/ResourcesYearn.sol";
import "../../../src/tgUSD/tokens/TgUSD.sol";
import "../../../src/tgUSD/tokens/TgStable.sol";
import "../../../src/tgUSD/Utilities/RewardAccumulator.sol";
import "../../../src/tgUSD/Utilities/Zapper.sol";
import "../../../src/tgUSD/Utilities/ControlTower.sol";
import "../../../src/tgUSD/Utilities/MarketCreator.sol";
import "../../../test/tgUSD/mocks/MockEnsoRouter.sol";
import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";
import "../../../src/tgUSD/Market/MarketNoSociabilization.sol";
import "../../utils/AssertERC20.sol";
import "../../utils/LowLevel.sol";
import "../../utils/EnsoUtils.sol";
import "../../utils/Labeliser.sol";
import "../../utils/Array.sol";
import "../../../src/interfaces/externals/YearnFi/IYearnV3Vault.sol";
import "../../../src/interfaces/externals/ICREATE3Factory.sol";

contract TgUSDDeployContext is StdCheats, StdUtils, AssertERC20, LowLevel {
    uint256 mainnetFork;
    uint256 baseFork;

    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    address processor = makeAddr("Processor");

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = makeAddr("feeTreasury");
    address public mockedLP = makeAddr("Mocked LP");

    address public l0EndpointMainnet = 0x1a44076050125825900e736c501f859c50fE728c;
    address public l0EndpointBase = 0x1a44076050125825900e736c501f859c50fE728c;

    ControlTower public controlTower;
    MarketCreator public marketCreator;
    address public convexCrvLPMarketImplem;
    address public convexFxnLPMarketImplem;
    address public marketNoSociabilizationImplem;
    Zapper public zapper;
    ICurveStableSwapNG public tgUSDLp;
    TgUSD public tgUsd;
    TgUSD public tgUsdBase;
    IYearnV3Vault public sgUSD;
    RewardAccumulator public rewardAccumulator;
    MockEnsoRouter public mockEnsoRouter;
    EnsoUtils public ensoUtils;
    Labeliser public labeliser;
    ICREATE3Factory public create3Factory = ICREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);

    constructor() {
        baseFork = vm.createSelectFork("base", 24379193);
        mainnetFork = vm.createSelectFork("mainnet", 21514132);

        vm.startPrank(owner);

        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketNoSociabilizationImplem = address(new MarketNoSociabilization());

        ensoUtils = new EnsoUtils();

        labeliser = new Labeliser();
        labeliser.labelizeERC20();
        labeliser.labelizeERC4626();

        controlTower = new ControlTower(owner, feeTreasury);

        rewardAccumulator = new RewardAccumulator(owner, controlTower, feeTreasury);

        // Deploy tgUSD on Base
        tgUsdBase = deployTgUSD(baseFork, l0EndpointBase);
        // Deploy tgUSD on Mainnet ETH
        tgUsd = deployTgUSD(mainnetFork, l0EndpointMainnet);

        assertEq(address(tgUsdBase), address(tgUsd), "Should be equals with CREATE3");

        sgUSD = IYearnV3Vault(AddrYearnFi.VAULT_FACTORY.deploy_new_vault(address(tgUsd), "Staked tgUSD", "sgUSD", owner, 7 days));

        mockEnsoRouter = new MockEnsoRouter();

        vm.allowCheatcodes(address(AddrAggregator.ENSO_ROUTER));
        zapper = new Zapper(owner, controlTower, tgUsd);

        controlTower.toggleZapper(address(zapper));

        deal(address(tgUsd), owner, 1_000_000 ether);

        // Deploy and addLiquidity in tgUSD LP
        tgUSDLp = deployTgUSDLP();

        vm.label(address(tgUsd), "tgUSD");
        vm.label(address(sgUSD), "sgUSD");
        vm.label(address(controlTower), "ControlTower");
        vm.label(address(tgUSDLp), "LP tgUSD");
        vm.label(address(rewardAccumulator), "RewardAccumulator");
        vm.label(address(AddrAggregator.ENSO_ROUTER), "Enso Router");
        vm.label(address(mockEnsoRouter), "Mock Odos Router");

        vm.stopPrank();
    }

    function getBytecodeWithConstructorArgs(address endpointAddress) public view returns (bytes memory) {
        string memory json = vm.readFile("./out/TgUSD.sol/TgUSD.json");
        bytes memory bytecode = abi.decode(vm.parseJson(json, ".bytecode.object"), (bytes));
        // console.logBytes(bytecode);

        // Encodez les arguments pour le constructeur
        bytes memory constructorArgs = abi.encode("Tangent StableCoin", "tgUSD", endpointAddress, owner, owner, controlTower);

        // Concaténez le bytecode et les arguments
        return abi.encodePacked(bytecode, constructorArgs);
    }

    function deployTgUSD(uint256 forkId, address endpoint) public returns (TgUSD) {
        vm.selectFork(forkId);
        return TgUSD(create3Factory.deploy(bytes32(0), getBytecodeWithConstructorArgs(endpoint)));
    }

    function deployTgUSDLP() public returns (ICurveStableSwapNG) {
        // Give usdc to owner before LP deployment
        deal(address(AddrClassicERC20.TOKEN_USDC), owner, 1_000_000 * 10 ** 6);
        vm.startPrank(owner);

        ICurveStableSwapNG lpTgUSD = ICurveStableSwapNG(
            AddrCurveStableLP.STABLE_SWAP_FACTORY.deploy_plain_pool(
                "tgUSD-USDC",
                "tgUSD-USDC",
                Array.memoryAddress([address(AddrClassicERC20.TOKEN_USDC), address(tgUsd)]),
                5000,
                100000000,
                0,
                866,
                0,
                Array.memoryUint8([uint8(0), uint8(0)]),
                Array.memoryBytes4([bytes4(0), bytes4(0)]),
                Array.memoryAddress([address(0), address(0)])
            )
        );

        AddrClassicERC20.TOKEN_USDC.approve(address(lpTgUSD), MAX_UINT);
        tgUsd.approve(address(lpTgUSD), MAX_UINT);

        lpTgUSD.add_liquidity(Array.memoryUint256([uint256(1_000_000 * 10 ** 6), uint256(1_000_000 ether)]), uint256(0));

        return lpTgUSD;
    }
}
