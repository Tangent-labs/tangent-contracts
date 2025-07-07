// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/libs/Resources/ResourcesConvex.sol";
import "../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../src/libs/Resources/ResourcesPendle.sol";
import "../../src/libs/Resources/ResourcesYearn.sol";

import "../../src/USG/Lock/VsTan.sol";
import "../../src/USG/Tokens/Tan.sol";
import "../../src/USG/Tokens/USG.sol";
import "../../src/USG/Tokens/WStable.sol";
import "../../src/USG/Rewards/RewardAccumulator.sol";
import "../../src/USG/Utilities/ControlTower.sol";
import "../../src/USG/Utilities/MarketCreator.sol";
import "../../src/USG/Utilities/ZappingProxy.sol";

import "../mocks/MockRouter.sol";

import "../../src/USG/Market/Convex/ConvexCrvLPMarket.sol";
import "../../src/USG/Market/Convex/ConvexFxnLPMarket.sol";
import "../../src/USG/Market/BasicERC20Market.sol";
import "../../src/USG/Market/abstract/MarketCore.sol";
import "../../src/USG/Market/abstract/DebtIR.sol";

import "../utils/AssertERC20.sol";
import "../utils/LowLevel.sol";
import "../utils/EnsoUtils.sol";
import "../utils/Labeliser.sol";
import "../utils/Array.sol";
import "../utils/String.sol";
import "../utils/Encoder.sol";
import "../../src/interfaces/externals/YearnFi/IYearnV3Vault.sol";
import "../../src/interfaces/externals/ICREATE3Factory.sol";

import "./LpDeploymentContext.sol";

contract USGDeployContext is StdCheats, StdUtils, AssertERC20, LowLevel {
    using SafeERC20 for IERC20Metadata;

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
    address public marketBasicERC20Implem;

    USG public usg;
    Tan public tan;
    VsTan public vsTan;
    USG public USGBase;
    IYearnV3Vault public sUSG;
    RewardAccumulator public rewardAccumulator;
    MockRouter public mockRouter;
    EnsoUtils public ensoUtils;
    Labeliser public labeliser;
    ICREATE3Factory public create3Factory = ICREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    LpDeploymentContext public lpDeploymentContext;

    constructor() {
        // baseFork = vm.createSelectFork("base", 24379193);
        mainnetFork = vm.createSelectFork("mainnet", 22596525);

        vm.startPrank(owner);

        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketBasicERC20 = address(new BasicERC20Market());

        encoder = new Encoder();
        ensoUtils = new EnsoUtils();
        labeliser = new Labeliser();

        labeliser.labelizeERC20();
        labeliser.labelizeERC4626();

        controlTower = new ControlTower(owner, feeTreasury);

        tan = new Tan(owner);

        // Deploy USG on Base
        // USGBase = deployUSG(baseFork, l0EndpointBase);
        // Deploy USG on Mainnet ETH
        usg = deployUSG(mainnetFork);

        // assertEq(address(USGBase), address(USG), "Should be equals with CREATE3");

        zappingProxy = new ZappingProxy();

        sUSG = IYearnV3Vault(AddrYearnFi.VAULT_FACTORY.deploy_new_vault(address(usg), "Staked USG", "sUSG", owner, 7 days));

        // Deposit Limit
        sUSG.add_role(owner, 256);
        // Set reward processor
        sUSG.add_role(owner, 32);

        sUSG.set_deposit_limit(MAX_UINT);

        deal(address(usg), owner, 1_500 ether);
        usg.approve(address(sUSG), MAX_UINT);
        sUSG.deposit(1_000 ether, owner);

        usg.transfer(address(sUSG), 500 ether);
        sUSG.process_report(address(sUSG));

        vsTan = new VsTan(owner, controlTower, tan, usg, sUSG, zappingProxy);
        vsTan.addNewReward(usg);

        mockRouter = new MockRouter();

        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V1));
        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V2));

        deal(address(usg), owner, 3_000_000 ether);

        vm.label(address(usg), "USG");
        vm.label(address(sUSG), "sUSG");
        vm.label(address(controlTower), "ControlTower");
        vm.label(address(tan), "Tan");
        vm.label(address(vsTan), "VsTan");

        vm.label(address(AddrRouter.ENSO_ROUTER_V1), "Enso Router V1");
        vm.label(address(AddrRouter.ENSO_ROUTER_V2), "Enso Router V2");

        vm.label(address(mockRouter), "Mock Router");
        vm.label(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e, "Curve Router");

        vm.label(address(zappingProxy), "Zapping Proxy");

        vm.label(address(convexCrvLPMarketImplem), "Implementation CvxCrvMarket");
        vm.label(address(convexFxnLPMarketImplem), "Implementation CvxFxnMarket");
        vm.label(address(marketBasicERC20Implem), "Implementation BasicERC20Market");

        vm.stopPrank();

        lpDeploymentContext = new LpDeploymentContext(owner, usg);
    }

    function getBytecodeWithConstructorArgs() public view returns (bytes memory) {
        string memory json = vm.readFile("./out/USG.sol/USG.json");
        bytes memory bytecode = abi.decode(vm.parseJson(json, ".bytecode.object"), (bytes));
        // console.logBytes(bytecode);

        // Encodez les arguments pour le constructeur
        bytes memory constructorArgs = abi.encode(owner, controlTower);

        // Concaténez le bytecode et les arguments
        return abi.encodePacked(bytecode, constructorArgs);
    }

    function deployUSG(uint256 forkId) public returns (USG) {
        vm.selectFork(forkId);
        return USG(create3Factory.deploy(bytes32(0), getBytecodeWithConstructorArgs()));
    }
}
