// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "../../../src/libs/Resources/ResourcesConvex.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/libs/Resources/ResourcesPendle.sol";
import "../../../src/libs/Resources/ResourcesYearn.sol";

import "../../../src/tgUSD/Lock/RsTanService.sol";
import "../../../src/tgUSD/Lock/RsTanERC721.sol";

import "../../../src/tgUSD/Tokens/Tan.sol";
import "../../../src/tgUSD/Tokens/TgUSD.sol";
import "../../../src/tgUSD/Tokens/WStable.sol";

import "../../../src/tgUSD/Rewards/RewardAccumulator.sol";
import "../../../src/tgUSD/Utilities/Zapper.sol";
import "../../../src/tgUSD/Utilities/ControlTower.sol";
import "../../../src/tgUSD/Utilities/MarketCreator.sol";
import "../../../src/tgUSD/Utilities/ZappingProxy.sol";
import "../../../test/tgUSD/mocks/MockEnsoRouter.sol";
import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";
import "../../../src/tgUSD/Market/MarketNoSociabilization.sol";
import "../../utils/AssertERC20.sol";
import "../../utils/LowLevel.sol";
import "../../utils/EnsoUtils.sol";
import "../../utils/Labeliser.sol";
import "../../utils/Array.sol";
import "../../utils/Encoder.sol";
import "../../../src/interfaces/externals/YearnFi/IYearnV3Vault.sol";
import "../../../src/interfaces/externals/ICREATE3Factory.sol";

import "./LpDeploymentContext.sol";

contract TgUSDDeployContext is StdCheats, StdUtils, AssertERC20, LowLevel {
    uint256 public mainnetFork;
    uint256 public baseFork;

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

    Encoder public encoder;

    ZappingProxy public zappingProxy;

    ControlTower public controlTower;
    MarketCreator public marketCreator;
    address public convexCrvLPMarketImplem;
    address public convexFxnLPMarketImplem;
    address public marketNoSociabilizationImplem;

    TgUSD public tgUSD;
    Tan public tan;
    RsTanService public rsTanService;
    RsTanERC721 public rsTanERC721;
    TgUSD public tgUsdBase;
    IYearnV3Vault public sgUSD;
    RewardAccumulator public rewardAccumulator;
    MockEnsoRouter public mockEnsoRouter;
    EnsoUtils public ensoUtils;
    Labeliser public labeliser;
    ICREATE3Factory public create3Factory = ICREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);

    LpDeploymentContext public lpDeploymentContext;

    constructor() {
        // baseFork = vm.createSelectFork("base", 24379193);
        mainnetFork = vm.createSelectFork("mainnet", 22346661);

        vm.startPrank(owner);

        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketNoSociabilizationImplem = address(new MarketNoSociabilization());

        encoder = new Encoder();
        ensoUtils = new EnsoUtils();
        labeliser = new Labeliser();

        labeliser.labelizeERC20();
        labeliser.labelizeERC4626();

        controlTower = new ControlTower(owner, feeTreasury);

        tan = new Tan();
        rsTanERC721 = new RsTanERC721(owner);

        // Deploy tgUSD on Base
        // tgUsdBase = deployTgUSD(baseFork, l0EndpointBase);
        // Deploy tgUSD on Mainnet ETH
        tgUSD = deployTgUSD(mainnetFork);

        // assertEq(address(tgUsdBase), address(tgUSD), "Should be equals with CREATE3");

        zappingProxy = new ZappingProxy();

        sgUSD = IYearnV3Vault(AddrYearnFi.VAULT_FACTORY.deploy_new_vault(address(tgUSD), "Staked tgUSD", "sgUSD", owner, 7 days));

        rsTanService = new RsTanService(owner, controlTower, tan, rsTanERC721, tgUSD, sgUSD);
        rsTanERC721.setService(address(rsTanService));
        rsTanService.addNewReward(tgUSD);

        mockEnsoRouter = new MockEnsoRouter();

        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V1));
        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V2));

        deal(address(tgUSD), owner, 3_000_000 ether);

        vm.label(address(tgUSD), "tgUSD");
        vm.label(address(sgUSD), "sgUSD");
        vm.label(address(controlTower), "ControlTower");
        vm.label(address(tan), "Tan");
        vm.label(address(rsTanService), "RsTanService");
        vm.label(address(rsTanERC721), "RsTanERC721");

        vm.label(address(AddrRouter.ENSO_ROUTER_V1), "Enso Router V1");
        vm.label(address(AddrRouter.ENSO_ROUTER_V2), "Enso Router V2");

        vm.label(address(mockEnsoRouter), "Mock Odos Router");
        vm.label(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e, "Curve Router");

        vm.label(address(zappingProxy), "Zapping Proxy");

        vm.label(address(convexCrvLPMarketImplem), "Implementation CvxCrvMarket");
        vm.label(address(convexFxnLPMarketImplem), "Implementation CvxFxnMarket");
        vm.label(address(marketNoSociabilizationImplem), "Implementation NoSocMarket");

        vm.stopPrank();

        lpDeploymentContext = new LpDeploymentContext(owner, tgUSD);
    }

    function getBytecodeWithConstructorArgs() public view returns (bytes memory) {
        string memory json = vm.readFile("./out/TgUSD.sol/TgUSD.json");
        bytes memory bytecode = abi.decode(vm.parseJson(json, ".bytecode.object"), (bytes));
        // console.logBytes(bytecode);

        // Encodez les arguments pour le constructeur
        bytes memory constructorArgs = abi.encode("Tangent StableCoin", "tgUSD", controlTower);

        // Concaténez le bytecode et les arguments
        return abi.encodePacked(bytecode, constructorArgs);
    }

    function deployTgUSD(uint256 forkId) public returns (TgUSD) {
        vm.selectFork(forkId);
        return TgUSD(create3Factory.deploy(bytes32(0), getBytecodeWithConstructorArgs()));
    }
}
