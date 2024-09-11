import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CurveLendSplitterToken} from "../src/tokens/CurveLendSplitterToken.sol";

import {gUSDSdt} from "../src/tokens/stakeDao/gUSDSdt.sol";
import {scvUSDSdt} from "../src/tokens/stakeDao/scvUSDSdt.sol";

import {gUSDCvx} from "../src/tokens/convex/gUSDCvx.sol";
import {scvUSDCvx} from "../src/tokens/convex/scvUSDCvx.sol";

import {ISdtLiquidityGauge} from "../src/interfaces/externals/ISdtLiquidityGauge.sol";
import {IStakeDaoVault} from "../src/interfaces/externals/IStakeDaoVault.sol";
import {ILlamaLendVault} from "../src/interfaces/externals/ILlamaLendVault.sol";

import {ILendRewardSplitter} from "../src/interfaces/internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../src/interfaces/internals/ICurveLendSplitterToken.sol";
import {ICommonStruct} from "../src/interfaces/internals/ICommonStruct.sol";
import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrGlobal,AddrCvxVaultTokens} from "../src/libs/Resources.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract LendRewardSplitterTestCommon is Test {
    uint256 public MAX_UINT = uint256(int256(-1));

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");

    IStakeDaoVault public constant stakeDaoVault = AddrSdtVaults.CRVUSD_CRV;
    ILlamaLendVault public constant llamalendVault = AddrLlamaLendVaults.CRVUSD_CRV;

    IERC20 public constant crvUSD = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
    LendRewardSplitter public splitter;
    address public gUSDBeaconSdt;
    address public scvUSDBeaconSdt;
    address public gUSDBeaconCvx;
    address public scvUSDBeaconCvx;

    scvUSDSdt public scvUSDImplem;
    gUSDSdt public gUSDImplem;

    ISdtLiquidityGauge public liquidityGauge;
    ILlamaLendVault public curveLendVault;
    address public proxyAdmin;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function fork() public {
        vm.createSelectFork("mainnet", 20513092);
    }

    function deployProxyAdmin() public {
        proxyAdmin = address(new ProxyAdmin(owner));
    }

    function deployGUSDBeaconSdt() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("gUSDSdt.sol:gUSDSdt", opts);
        }
        //deploy
        gUSDBeaconSdt = address(new UpgradeableBeacon(address(new gUSDSdt()), (owner)));
    }

    function deploySCVUSDBeaconSdt() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("scvUSDSdt.sol:scvUSDSdt", opts);
        }
        //deploy
        scvUSDBeaconSdt = address(new UpgradeableBeacon(address(new scvUSDSdt()), (owner)));
    }

    function deployGUSDBeaconCvx() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("gUSDCvx.sol:gUSDCvx", opts);
        }
        //deploy
        gUSDBeaconCvx = address(new UpgradeableBeacon(address(new gUSDCvx()), (owner)));
    }

    function deploySCVUSDBeaconCvx() public {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("scvUSDCvx.sol:scvUSDCvx", opts);
        }
        //deploy
        scvUSDBeaconCvx = address(new UpgradeableBeacon(address(new scvUSDCvx()), (owner)));
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
                    abi.encodeCall(LendRewardSplitter.initialize, (owner, gUSDBeaconSdt, scvUSDBeaconSdt, gUSDBeaconCvx, scvUSDBeaconCvx))
                )
            )
        );
    }

    function setUpSplitter() public {
        //Proxys
        deployProxyAdmin();
        deployGUSDBeaconSdt();
        deploySCVUSDBeaconSdt();
        deployGUSDBeaconCvx();
        deploySCVUSDBeaconCvx();
        deploySplitterProxy();

        //create StakeDao Market
        vm.prank(owner);
        splitter.createSdtMarket(AddrSdtVaults.CRVUSD_CRV);
        liquidityGauge = splitter.sdtGaugePerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        curveLendVault = AddrLlamaLendVaults.CRVUSD_CRV;
        scvUSDImplem = scvUSDSdt(address(splitter.scvUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));
        gUSDImplem = gUSDSdt(address(splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));

        //labelizing
        vm.label(AddrClassicERC20.TOKEN_CRVUSD, "crvUSD");
        vm.label(address(AddrSdtVaults.CRVUSD_CRV), "CRVUSD_CRV");
        vm.label(address(AddrLlamaLendVaults.CRVUSD_CRV), "LLAMALEND_CRVUSD_CRV");
        vm.label(AddrSdtVaults.CRVUSD_CRV.strategy(), "STAKEDAO_CRV_STRATEGY");
        vm.label(AddrSdtVaults.CRVUSD_CRV.liquidityGauge(), "STAKEDAO_CRV_LIQUIDITY_GAUGE");
        vm.label(address(scvUSDImplem), "scvUSD");
        vm.label(address(gUSDImplem), "gUSD");

        vm.label(address(AddrGlobal.CVX_BOOSTER), "CVX_BOOSTER");
        vm.label(address(AddrCvxVaultTokens.CRVUSD_CRV), "CVX_VAULT_CRV_CRVUSD");

        vm.label(address(AddrGlobal.CRVUSD_CONTROLLER), "CRVUSD_CONTROLLER");
    }

    function deposit(uint256 amount, bool isStableReward, bool doDeposit, address tokenIn) public returns (uint256) {
        ILendRewardSplitter.SDT_TOKEN_TYPE typeAsset = ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset;
        if (tokenIn == address(AddrLlamaLendVaults.CRVUSD_CRV)) {
            typeAsset = ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset;
        } else if (tokenIn == address(AddrSdtVaults.CRVUSD_CRV)) {
            typeAsset = ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset;
        }
        return splitter.depositSdt(llamalendVault, typeAsset, amount, isStableReward, doDeposit);
    }

    function widthraw(uint256 depositAmount, bool isStableReward, ILendRewardSplitter.SDT_TOKEN_TYPE tokenOutType) public {
        splitter.withdrawSdt(llamalendVault, tokenOutType, depositAmount, isStableReward);
    }

    function getUser(uint256 index, address token, uint256 amount) public returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == address(AddrSdtVaults.CRVUSD_CRV)) {
            token = address(liquidityGauge);
        }
        vm.startPrank(user);
        deal(token, user, amount);
        IERC20(token).approve(address(splitter), MAX_UINT);
    }

    function getUser(uint256 index, address token) public returns (address user) {
        return getUser(index, token, 1000 ether);
    }

    function _takesGaugeOnwershipAndSetDistributor(ISdtLiquidityGauge _sdtLiquidityGauge) public {
        vm.deal(ownerGauge, 10 ether);
        address admin = _sdtLiquidityGauge.admin();
        uint256 rewardCount = _sdtLiquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            vm.startPrank(ownerGauge);
            IERC20 token = IERC20(_sdtLiquidityGauge.reward_tokens(i));
            token.approve(address(_sdtLiquidityGauge), 0);
            token.approve(address(_sdtLiquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            _sdtLiquidityGauge.set_reward_distributor(address(token), ownerGauge);
            unchecked {
                ++i;
            }
        }
    }

    function _distributeGaugeRewards(ISdtLiquidityGauge _sdtLiquidityGauge, ICommonStruct.TokenAmount[] memory tokenAmounts) public {
        for (uint256 i; i < tokenAmounts.length; ) {
            vm.startPrank(ownerGauge);
            deal(address(tokenAmounts[i].token), ownerGauge, tokenAmounts[i].amount);
            _sdtLiquidityGauge.deposit_reward_token(address(tokenAmounts[i].token), tokenAmounts[i].amount);
            vm.stopPrank();

            unchecked {
                ++i;
            }
        }
        vm.stopPrank();
    }
}
