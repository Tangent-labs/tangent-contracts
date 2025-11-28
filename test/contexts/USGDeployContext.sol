// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/libs/Resources/ResourcesConvex.sol";
import "../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../src/libs/Resources/ResourcesPendle.sol";
import "../../src/libs/Resources/ResourcesYearn.sol";
import "../../src/libs/Resources/ResourcesStakeDao.sol";

import "../../src/USG/Tokens/VsTAN.sol";
import "../../src/USG/Tokens/TAN.sol";
import "../../src/USG/Tokens/USG.sol";
import "../../src/USG/Tokens/WStable.sol";
import "../../src/USG/Utilities/RewardAccumulator.sol";
import "../../src/USG/Utilities/ControlTower.sol";
import "../../src/USG/Utilities/MarketCreator.sol";
import "../../src/USG/Utilities/MarketViewer.sol";
import "../../src/USG/Utilities/ZappingProxy.sol";
import "../../src/USG/Utilities/Migratoor.sol";
import "../../src/USG/Utilities/abstract/LightReentrancyGuardTransient.sol";
import "../../src/USG/Routers/PendlePTRouter.sol";

import "../mocks/MockRouter.sol";

import "../../src/USG/Market/Convex/ConvexCrvLPMarket.sol";
import "../../src/USG/Market/Convex/ConvexFxnLPMarket.sol";
import "../../src/USG/Market/BasicERC20Market.sol";
import "../../src/USG/Market/Curve/CurveGaugeMarket.sol";
import "../../src/USG/Market/StakeDao/StakeDaoVaultV2Market.sol";

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
import "forge-std/console.sol";

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
    address public pauser = makeAddr("Pauser");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = 0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7;
    address public mockedLP = makeAddr("Mocked LP");

    Encoder public encoder;

    ZappingProxy public zappingProxy;

    ControlTower public controlTower;
    MarketCreator public marketCreator;
    MarketViewer public marketViewer;

    address public convexCrvLPMarketImplem;
    address public convexFxnLPMarketImplem;
    address public marketBasicERC20Implem;
    address public curveGaugeMarketImplem;
    address public stakeDaoVaultV2MarketImplem;

    USG public usg;
    TAN public tan;
    VsTAN public vsTan;
    USG public USGBase;
    IYearnV3Vault public sUSG;
    IYearnV3Vault public sTAN;

    RewardAccumulator public rewardAccumulator;
    Migratoor public migratoor;

    MockRouter public mockRouter;
    EnsoUtils public ensoUtils;
    Labeliser public labeliser;
    ICREATE3Factory public create3Factory = ICREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);
    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    LpDeploymentContext public lpDeploymentContext;

    PendlePTRouter public pendlePTRouter;

    constructor() {
        // baseFork = vm.createSelectFork("base", 24379193);
        mainnetFork = vm.createSelectFork("mainnet", 23796875);

        vm.startPrank(owner);

        convexCrvLPMarketImplem = address(new ConvexCrvLPMarket());
        convexFxnLPMarketImplem = address(new ConvexFxnLPMarket());
        marketBasicERC20Implem = address(new BasicERC20Market());

        curveGaugeMarketImplem = address(new CurveGaugeMarket());
        stakeDaoVaultV2MarketImplem = address(new StakeDaoVaultV2Market());
        marketViewer = new MarketViewer();

        encoder = new Encoder();
        ensoUtils = new EnsoUtils();
        labeliser = new Labeliser();

        labeliser.labelizeERC20();
        labeliser.labelizeERC4626();

        pendlePTRouter = new PendlePTRouter();

        controlTower = new ControlTower(owner, feeTreasury);

        tan = new TAN(owner);

        // Deploy USG on Base
        // USGBase = deployUSG(baseFork, l0EndpointBase);
        // Deploy USG on Mainnet ETH
        usg = deployUSG(mainnetFork);

        // assertEq(address(USGBase), address(USG), "Should be equals with CREATE3");

        zappingProxy = new ZappingProxy(controlTower);

        migratoor = new Migratoor(controlTower, zappingProxy);

        controlTower.togglePositionMigrator(address(migratoor));
        controlTower.togglePauser(pauser);

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

        sTAN = IYearnV3Vault(AddrYearnFi.VAULT_FACTORY.deploy_new_vault(address(tan), "Staked TAN", "sTAN", owner, 7 days));

        // Deposit Limit
        sTAN.add_role(owner, 256);
        // Set reward processor
        sTAN.add_role(owner, 32);

        sTAN.set_deposit_limit(MAX_UINT);

        deal(address(tan), owner, 1_500 ether);
        tan.approve(address(sTAN), MAX_UINT);
        sTAN.deposit(1_000 ether, owner);

        tan.transfer(address(sTAN), 500 ether);
        sTAN.process_report(address(sTAN));

        deal(address(tan), owner, 9_998_500 ether);

        vsTan = new VsTAN(owner, controlTower, tan, usg, sUSG, zappingProxy, 100 ether);
        vsTan.addNewReward(usg);

        mockRouter = new MockRouter();

        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V1));
        vm.allowCheatcodes(address(AddrRouter.ENSO_ROUTER_V2));

        deal(address(usg), owner, 3_000_000 ether);

        vm.label(address(usg), "USG");
        vm.label(address(sUSG), "sUSG");
        vm.label(address(controlTower), "ControlTower");
        vm.label(address(tan), "TAN");
        vm.label(address(vsTan), "VsTAN");

        vm.label(address(AddrRouter.ENSO_ROUTER_V1), "Enso Router V1");
        vm.label(address(AddrRouter.ENSO_ROUTER_V2), "Enso Router V2");

        vm.label(address(mockRouter), "Mock Router");
        vm.label(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e, "Curve Router");

        vm.label(address(zappingProxy), "Zapping Proxy");

        vm.label(address(convexCrvLPMarketImplem), "Implementation CvxCrvMarket");
        vm.label(address(convexFxnLPMarketImplem), "Implementation CvxFxnMarket");
        vm.label(address(marketBasicERC20Implem), "Implementation BasicERC20Market");
        vm.stopPrank();

        lpDeploymentContext = new LpDeploymentContext(owner, usg, tan);
    }

    function getBytecodeWithConstructorArgs() public view returns (bytes memory) {
        string memory json = vm.readFile("./out/USG.sol/USG.json");
        bytes memory bytecode = abi.decode(vm.parseJson(json, ".bytecode.object"), (bytes));

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
