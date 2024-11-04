import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SplitterToken} from "../../../src/LendSplitter/tokens/SplitterToken.sol";

import {LendRewardSplitter} from "../../../src/LendSplitter/LendRewardSplitter.sol";
import {gUSDCvx} from "../../../src/LendSplitter/tokens/gUSDCvx.sol";
import {scvUSDCvx} from "../../../src/LendSplitter/tokens/scvUSDCvx.sol";
import {SplitterTokenComp} from "../../../src/LendSplitter/tokens/SplitterTokenComp.sol";
import {ISdtLiquidityGauge} from "../../../src/interfaces/externals/StakeDao/ISdtLiquidityGauge.sol";
import {IStakeDaoVault} from "../../../src/interfaces/externals/StakeDao/IStakeDaoVault.sol";
import {ILlamaVault} from "../../../src/interfaces/externals/LlamaLend/ILlamaVault.sol";

import {ILendRewardSplitter} from "../../../src/interfaces/internals/LendSplitter/ILendRewardSplitter.sol";
import {ISplitterToken} from "../../../src/interfaces/internals/LendSplitter/ISplitterToken.sol";
import {ICommonStruct} from "../../../src/interfaces/internals/ICommonStruct.sol";
import "../../../src/libs/resources/ResourcesGlobal.sol";
import "../../../src/libs/resources/ResourcesYieldSplitter.sol";

import "forge-std/console.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract DeployContext is StdCheats, StdUtils, Test {
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    address processor = makeAddr("Processor");

    uint256 public MAX_UINT = uint256(int256(-1));

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = makeAddr("feeTreasury");
    LendRewardSplitter public splitter;
    address public gUSDBeaconCvx;
    address public scvUSDBeaconCvx;
    address public scvUSDBeaconCompounder;
    address public proxyAdmin;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function deployBaseContracts() public {
        vm.createSelectFork("mainnet", 20725852);
        //Proxys
        deployProxyAdmin();
        deployGUSDBeaconCvx();
        deploySCVUSDBeaconCvx();
        deployScvUSDCompounder();
        deploySplitterProxy(owner);

        vm.startPrank(owner);
        splitter.toggleZapToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        splitter.toggleZapToken(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        splitter.toggleZapToken(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        vm.stopPrank();

        //labelizing
        vm.label(address(splitter), "SPLITTER");
        vm.label(address(AddrClassicERC20.TOKEN_CRVUSD), "crvUSD");
        vm.label(address(AddrGlobal.CVX_BOOSTER), "CVX_BOOSTER");
    }

    function deployProxyAdmin() public {
        proxyAdmin = address(new ProxyAdmin(owner));
    }

    function deployGUSDBeaconCvx() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("gUSDCvx.sol:gUSDCvx", opts);
        }
        //deploy
        gUSDBeaconCvx = address(new UpgradeableBeacon(address(new gUSDCvx()), (owner)));
        return gUSDBeaconCvx;
    }

    function deploySCVUSDBeaconCvx() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("scvUSDCvx.sol:scvUSDCvx", opts);
        }
        //deploy
        scvUSDBeaconCvx = address(new UpgradeableBeacon(address(new scvUSDCvx()), (owner)));
        return scvUSDBeaconCvx;
    }

    function deployScvUSDCompounder() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("SplitterTokenComp.sol:SplitterTokenComp", opts);
        }
        //deploy
        scvUSDBeaconCompounder = address(new UpgradeableBeacon(address(new SplitterTokenComp()), (owner)));
        return scvUSDBeaconCompounder;
    }

    function deploySplitterProxy(address ownerToSet) public returns (LendRewardSplitter) {
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
                    abi.encodeCall(LendRewardSplitter.initialize, (ownerToSet, feeTreasury, gUSDBeaconCvx, scvUSDBeaconCvx, scvUSDBeaconCompounder))
                )
            )
        );
        return splitter;
    }

    function deal(IERC20 erc20, address to, uint256 amount) public {
        deal(address(erc20), to, amount);
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
