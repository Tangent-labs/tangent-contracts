import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CurveLendSplitterTokenStream} from "../src/tokens/CurveLendSplitterTokenStream.sol";
import {ISDLiquidityGauge} from "../src/interfaces/ISDLiquidityGauge.sol";
import {IStakeDaoVault} from "../src/interfaces/IStakeDaoVault.sol";
import {ICurveLendVault} from "../src/interfaces/ICurveLendVault.sol";
import {Addresses} from "../src/libs/Addresses.sol";

contract LendRewardSplitterTestCommon is Test {
    uint256 public MAX_UINT = uint256(int256(-1));

    // lendAsset
    address public TOKEN_crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    // Vaulted crvUSD
    address public CURVE_CRV_VAULT = 0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA; // Vaulted cvcrvUSD
    // Vaulted crvUSD in stake DAO
    address public STAKEDAO_CRV_VAULT = 0xfa6D40573082D797CB3cC378c0837fB90eB043e5;

    address owner = makeAddr("Owner");
    address ownerGauge = makeAddr("ownerGauge");

    IStakeDaoVault public constant stakeDaoVault = IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT);
    IERC20 public constant crvUSD = IERC20(Addresses.TOKEN_CRVUSD);
    LendRewardSplitter public splitter;
    CurveLendSplitterTokenStream public scvUSD;
    CurveLendSplitterTokenStream public gUSD;
    ISDLiquidityGauge public liquidityGauge;

    ICurveLendVault public curveLendVault;

    function fork() public {
        vm.createSelectFork("mainnet", 20513092);
    }

    function setUpSplitter() public returns (LendRewardSplitter) {
        //labelizing
        vm.label(TOKEN_crvUSD, "crvUSD");
        vm.label(STAKEDAO_CRV_VAULT, "STAKEDAO_CRV_VAULT");
        vm.label(CURVE_CRV_VAULT, "CURVE_CRV_VAULT");
        vm.label(IStakeDaoVault(STAKEDAO_CRV_VAULT).strategy(), "STAKEDAO_CRV_STRATEGY");
        vm.label(IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge(), "STAKEDAO_CRV_LIQUIDITY_GAUGE");

        //deploy splitter
        splitter = new LendRewardSplitter();
        vm.prank(owner);
        splitter.initialize();

        //create market
        vm.prank(owner);
        splitter.createMarket(stakeDaoVault);

        LendRewardSplitter.MarketStruct memory market = splitter.getMarket(address(stakeDaoVault));

        //Init vars
        liquidityGauge = market.liquidityGauge;
        curveLendVault = market.curveLendVault;
        scvUSD = market.scvUSD;
        gUSD = market.gUSD;

        return splitter;
    }

    function deposit(uint256 amount, bool isStableReward, bool doDeposit, address tokenIn) public returns (uint256) {
        LendRewardSplitter.TOKEN_TYPE typeAsset = LendRewardSplitter.TOKEN_TYPE.LendAsset;
        if (tokenIn == CURVE_CRV_VAULT) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendCurveAsset;
        } else if (tokenIn == STAKEDAO_CRV_VAULT) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset;
        }
        return splitter.deposit(address(stakeDaoVault), typeAsset, amount, isStableReward, doDeposit);
    }

    function widthraw(uint256 depositAmount, bool isStableReward, LendRewardSplitter.TOKEN_TYPE tokenOutType) public {
        splitter.withdraw(address(stakeDaoVault), tokenOutType, depositAmount, isStableReward);
    }

    function getUser(uint256 index, address token, uint256 amount) public returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == STAKEDAO_CRV_VAULT) {
            token = address(liquidityGauge);
        }
        vm.startPrank(user);
        deal(token, user, amount);
        IERC20(token).approve(address(splitter), MAX_UINT);
    }

    function getUser(uint256 index, address token) public returns (address user) {
        return getUser(index, token, 1000 ether);
    }

    function _takesGaugeOnwershipAndSetDistributor() public {
        vm.deal(ownerGauge, 10 ether);
        address admin = liquidityGauge.admin();
        uint256 rewardCount = liquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            IERC20 token = IERC20(liquidityGauge.reward_tokens(i));
            vm.prank(ownerGauge);
            token.approve(address(liquidityGauge), 0);
            vm.prank(ownerGauge);
            token.approve(address(liquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            liquidityGauge.set_reward_distributor(address(token), ownerGauge);
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
    function _distributeGaugeRewards(DistributionGauge[] memory distributionGauges) public {
        for (uint256 i; i < distributionGauges.length; ) {
            vm.prank(ownerGauge);
            deal(distributionGauges[i].token, ownerGauge, distributionGauges[i].amount);
            vm.prank(ownerGauge);
            liquidityGauge.deposit_reward_token(distributionGauges[i].token, distributionGauges[i].amount);
            unchecked {
                ++i;
            }
        }
        vm.stopPrank();
    }
}
