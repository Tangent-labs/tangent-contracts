import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CurveLendSplitterToken} from "../src/tokens/CurveLendSplitterToken.sol";
import {ISDLiquidityGauge} from "../src/interfaces/ISDLiquidityGauge.sol";
import {IStakeDaoVault} from "../src/interfaces/IStakeDaoVault.sol";
import {ICurveLendVault} from "../src/interfaces/ICurveLendVault.sol";
import {Addr} from "../src/libs/Addr.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract LendRewardSplitterTestCommon is Test {
    uint256 public MAX_UINT = uint256(int256(-1));

    address owner = makeAddr("Owner");
    address ownerGauge = makeAddr("ownerGauge");

    IStakeDaoVault public constant stakeDaoVault = IStakeDaoVault(Addr.STAKEDAO_CRVUSD_CRV);
    IERC20 public constant crvUSD = IERC20(Addr.TOKEN_CRVUSD);
    LendRewardSplitter public splitter;
    address public beaconCurveLendSplitterToken;
    CurveLendSplitterToken public scvUSD;
    CurveLendSplitterToken public gUSD;
    ISDLiquidityGauge public liquidityGauge;
    ICurveLendVault public curveLendVault;
    address public proxyAdmin;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function fork() public {
        vm.createSelectFork("mainnet", 20513092);
    }
    function deployProxyAdmin() public {
        proxyAdmin = address(new ProxyAdmin(owner));
    }
    function deployBeaconCurveLendSplitterToken() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("CurveLendSplitterToken.sol:CurveLendSplitterToken", opts);
        }
        //deploy
        beaconCurveLendSplitterToken = address(new UpgradeableBeacon(address(new CurveLendSplitterToken()), (owner)));
    }
    function deploySplitterProxy() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("LendRewardSplitter.sol:LendRewardSplitter", opts);
        }
        //deploy
        splitter = LendRewardSplitter(
            address(
                new TransparentUpgradeableProxy(
                    address(new LendRewardSplitter()),
                    proxyAdmin,
                    abi.encodeCall(LendRewardSplitter.initialize, (owner, beaconCurveLendSplitterToken))
                )
            )
        );
    }

    function setUpSplitter() public {
        //Proxys
        deployProxyAdmin();
        deployBeaconCurveLendSplitterToken();
        deploySplitterProxy();

        //create market
        vm.prank(owner);
        splitter.createMarket(Addr.STAKEDAO_CRVUSD_CRV);
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(Addr.STAKEDAO_CRVUSD_CRV);

        //Init vars
        liquidityGauge = market.liquidityGauge;
        curveLendVault = market.curveLendVault;
        scvUSD = market.scvUSD;
        gUSD = market.gUSD;

        //labelizing
        vm.label(Addr.TOKEN_CRVUSD, "crvUSD");
        vm.label(Addr.STAKEDAO_CRVUSD_CRV, "STAKEDAO_CRVUSD_CRV");
        vm.label(Addr.CURVE_CRVUSD_CRV, "CURVE_CRVUSD_CRV");
        vm.label(IStakeDaoVault(Addr.STAKEDAO_CRVUSD_CRV).strategy(), "STAKEDAO_CRV_STRATEGY");
        vm.label(IStakeDaoVault(Addr.STAKEDAO_CRVUSD_CRV).liquidityGauge(), "STAKEDAO_CRV_LIQUIDITY_GAUGE");
        vm.label(address(scvUSD), "scvUSD");
        vm.label(address(gUSD), "gUSD");
    }

    function deposit(uint256 amount, bool isStableReward, bool doDeposit, address tokenIn) public returns (uint256) {
        LendRewardSplitter.TOKEN_TYPE typeAsset = LendRewardSplitter.TOKEN_TYPE.LendAsset;
        if (tokenIn == Addr.CURVE_CRVUSD_CRV) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendCurveAsset;
        } else if (tokenIn == Addr.STAKEDAO_CRVUSD_CRV) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset;
        }
        return splitter.deposit(address(stakeDaoVault), typeAsset, amount, isStableReward, doDeposit);
    }

    function widthraw(uint256 depositAmount, bool isStableReward, LendRewardSplitter.TOKEN_TYPE tokenOutType) public {
        splitter.withdraw(address(stakeDaoVault), tokenOutType, depositAmount, isStableReward);
    }

    function getMarket() view external   returns  (LendRewardSplitter.MarketStruct  memory  )  {
        return splitter.getMarket(address(stakeDaoVault));
    }
    function getUser(uint256 index, address token, uint256 amount) public returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == Addr.STAKEDAO_CRVUSD_CRV) {
            token = address(liquidityGauge);
        }
        vm.startPrank(user);
        deal(token, user, amount);
        IERC20(token).approve(address(splitter), MAX_UINT);
    }

    function getUser(uint256 index, address token) public returns (address user) {
        return getUser(index, token, 1000 ether);
    }

    function _takesGaugeOnwershipAndSetDistributor(address _stakeDaoVault) public {
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(_stakeDaoVault);
        ISDLiquidityGauge _liquidityGauge = market.liquidityGauge;
        vm.deal(ownerGauge, 10 ether);
        address admin = _liquidityGauge.admin();
        uint256 rewardCount = _liquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            IERC20 token = IERC20(_liquidityGauge.reward_tokens(i));
            vm.prank(ownerGauge);
            token.approve(address(_liquidityGauge), 0);
            vm.prank(ownerGauge);
            token.approve(address(_liquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            _liquidityGauge.set_reward_distributor(address(token), ownerGauge);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }
    }
    struct DistributionGauge {
        address token;
        uint256 amount;
    }
    function _distributeGaugeRewards(address _stakeDaoVault, DistributionGauge[] memory distributionGauges) public {
        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(_stakeDaoVault);
        ISDLiquidityGauge _liquidityGauge = market.liquidityGauge;
        for (uint256 i; i < distributionGauges.length; ) {
            vm.prank(ownerGauge);
            deal(distributionGauges[i].token, ownerGauge, distributionGauges[i].amount);
            vm.prank(ownerGauge);
            _liquidityGauge.deposit_reward_token(distributionGauges[i].token, distributionGauges[i].amount);
            unchecked {
                ++i;
            }
        }
        vm.stopPrank();
    }
}
