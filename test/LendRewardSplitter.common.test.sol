import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokensvcUSD} from "../src/tokens/TokensvcUSD.sol";
import {TokengUsd} from "../src/tokens/TokengUsd.sol";
import {IStakeDaoVault} from "../src/interfaces/IStakeDaoVault.sol";
import {ICurvelendVault} from "../src/interfaces/ICurvelendVault.sol";

contract LendRewardSplitterTestCommon is Test {
    uint256 public MAX_INT = uint256(int256(-1));

    // lendAsset
    address public TOKEN_crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    // Vaulted crvUSD
    address public CURVE_CRV_VAULT = 0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA; // Vaulted cvcrvUSD
    // Vaulted crvUSD in stake DAO
    address public STAKEDAO_CRV_VAULT = 0xfa6D40573082D797CB3cC378c0837fB90eB043e5;

    LendRewardSplitter public splitter;
    TokensvcUSD public svcUSD;
    TokengUsd public gUSD;
    IERC20 public liquidityGauge;
    IERC20 public crvUSD;
    ICurvelendVault public curvelendVault;
    IStakeDaoVault public stakeDaoLendVault;

    function fork() public {
        vm.createSelectFork("mainnet", 20513092);
    }

    function setUpSplitter() public returns (LendRewardSplitter) {
        stakeDaoLendVault = IStakeDaoVault(STAKEDAO_CRV_VAULT);
        liquidityGauge = IERC20(stakeDaoLendVault.liquidityGauge());
        curvelendVault = ICurvelendVault(CURVE_CRV_VAULT);
        stakeDaoLendVault = IStakeDaoVault(STAKEDAO_CRV_VAULT);
        svcUSD = new TokensvcUSD("CRV", STAKEDAO_CRV_VAULT);
        gUSD = new TokengUsd("CRV", STAKEDAO_CRV_VAULT);
        crvUSD = IERC20(TOKEN_crvUSD);
        splitter = new LendRewardSplitter();
        svcUSD.setSplitterContract(address(splitter));
        gUSD.setSplitterContract(address(splitter));

        vm.label(TOKEN_crvUSD, "crvUSD");
        vm.label(STAKEDAO_CRV_VAULT, "STAKEDAO_CRV_VAULT");
        vm.label(CURVE_CRV_VAULT, "CURVE_CRV_VAULT");
        vm.label(IStakeDaoVault(STAKEDAO_CRV_VAULT).strategy(), "STAKEDAO_CRV_STRATEGY");
        vm.label(IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge(), "STAKEDAO_CRV_LIQUIDITY_GAUGE");
        splitter.initialize(CURVE_CRV_VAULT, STAKEDAO_CRV_VAULT, address(gUSD), address(svcUSD));

        return splitter;
    }

    function deposit(uint256 amount, bool isStableReward, bool doDeposit, address tokenIn) public returns (uint256) {
        LendRewardSplitter.TOKEN_TYPE typeAsset = LendRewardSplitter.TOKEN_TYPE.LendAsset;
        if (tokenIn == CURVE_CRV_VAULT) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendCurveAsset;
        } else if (tokenIn == STAKEDAO_CRV_VAULT) {
            typeAsset = LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset;
        }
        return splitter.deposit(typeAsset, amount, isStableReward, doDeposit);
    }

    function widthraw(uint256 depositAmount, bool isStableReward, LendRewardSplitter.TOKEN_TYPE tokenOutType) public {
        splitter.withdraw(tokenOutType, depositAmount, isStableReward);
    }

    function getUser(uint256 index, address token, uint256 amount) public returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == STAKEDAO_CRV_VAULT) {
            token = IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge();
        }
        vm.startPrank(user);
        deal(token, user, amount);
        IERC20(token).approve(address(splitter), MAX_INT);
    }

    function getUser(uint256 index, address token) public returns (address user) {
        return getUser(index, token, 1000 ether);
    }
}
