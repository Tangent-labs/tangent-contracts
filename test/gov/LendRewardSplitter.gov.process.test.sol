// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CurveLendSplitterTokenStream} from "../../src/tokens/CurveLendSplitterTokenStream.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurveLendVault} from "../../src/interfaces/ICurveLendVault.sol";
import {Addresses} from "../../src/libs/Addresses.sol";
import {ISDLiquidityGauge} from "../../src/interfaces/ISDLiquidityGauge.sol";

contract LendRewardSplitterGovProcessTest is Test {
    uint256 constant MAX_UINT = uint256(int256(-1));

    LendRewardSplitter splitter;
    CurveLendSplitterTokenStream scvUSD;
    CurveLendSplitterTokenStream gUSD;
    IERC20 liquidityGauge;
    ICurveLendVault curveLendVault;
    bool isStableReward = false;
    address owner = makeAddr("Owner");

    function _getUser(
        uint index,
        address token
    ) internal returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == Addresses.STAKEDAO_CRV_VAULT) {
            token = IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT)
                .liquidityGauge();
        }
        vm.startPrank(user);
        deal(token, user, 1000 ether);
        IERC20(token).approve(address(splitter), MAX_UINT);
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 20513092);
        vm.deal(owner, 10 ether);

        liquidityGauge = IERC20(
            IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).liquidityGauge()
        );
        curveLendVault = ICurveLendVault(Addresses.CURVE_CRV_VAULT);

        scvUSD = new CurveLendSplitterTokenStream(
            "Stable USD/CRV",
            "scvUSD-CRV"
        );
        gUSD = new CurveLendSplitterTokenStream(
            "Governance USD/CRV",
            "gUSD-CRV"
        );
        splitter = new LendRewardSplitter();

        scvUSD.setLendRewardSplitter(address(splitter));
        gUSD.setLendRewardSplitter(address(splitter));
        //labelizing
        vm.label(Addresses.TOKEN_CRVUSD, "crvUSD");
        vm.label(Addresses.STAKEDAO_CRV_VAULT, "STAKEDAO_CRV_VAULT");
        vm.label(Addresses.CURVE_CRV_VAULT, "CURVE_CRV_VAULT");
        vm.label(
            IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).strategy(),
            "STAKEDAO_CRV_STRATEGY"
        );
        vm.label(
            IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).liquidityGauge(),
            "STAKEDAO_CRV_LIQUIDITY_GAUGE"
        );
        /*
            address _curveLendVault,
            address _stakeDaoVault,
            address _curveGauge
        */
        splitter.initialize(
            Addresses.CURVE_CRV_VAULT,
            Addresses.STAKEDAO_CRV_VAULT,
            address(gUSD),
            address(scvUSD)
        );

        //deposit
        address tokenIn = Addresses.TOKEN_CRVUSD;
        _getUser(1, tokenIn);
        bool doDeposit = true;
        uint256 depositedAmount = 1000 ether;
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositedAmount,
            isStableReward,
            doDeposit
        );
        vm.stopPrank();
        skip(3600);
        _takesGaugeOnwershipAndSetDistributor();
    }

    function _takesGaugeOnwershipAndSetDistributor() internal {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(
            address(liquidityGauge)
        );
        address admin = _liquidityGauge.admin();
        uint256 rewardCount = _liquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            IERC20 token = IERC20(_liquidityGauge.reward_tokens(i));
            vm.prank(owner);
            token.approve(address(liquidityGauge), 0);
            vm.prank(owner);
            token.approve(address(liquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            _liquidityGauge.set_reward_distributor(address(token), owner);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }
    }
    function _distributeGaugeRewards() internal {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(
            address(liquidityGauge)
        );
        vm.prank(owner);
        deal(Addresses.TOKEN_SDT, owner, 10000 ether);
        deal(Addresses.TOKEN_CRV, owner, 10000 ether);
        deal(Addresses.TOKEN_CVX, owner, 10000 ether);
        deal(Addresses.TOKEN_CRVUSD, owner, 10000 ether);

        vm.prank(owner);
        _liquidityGauge.deposit_reward_token(Addresses.TOKEN_SDT, 10 ether);
        vm.prank(owner);
        _liquidityGauge.deposit_reward_token(Addresses.TOKEN_CRV, 100 ether);
        vm.prank(owner);
        _liquidityGauge.deposit_reward_token(Addresses.TOKEN_CVX, 20 ether);
        vm.prank(owner);
        _liquidityGauge.deposit_reward_token(
            Addresses.TOKEN_CRVUSD,
            1000 ether
        );
        vm.stopPrank();
    }
    function testProcessGovRewards() external {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(
            address(liquidityGauge)
        );
        _distributeGaugeRewards();
        skip(72000);
        uint256 sdtClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_SDT
        );
        uint256 crvClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRV
        );
        uint256 cvxClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CVX
        );
        uint256 crvUsdClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRVUSD
        );
        splitter.processRewards();
        IERC20[] memory rewardTokens = gUSD.getRewardTokens();
        assertEq(address(rewardTokens[0]), Addresses.TOKEN_SDT);
        assertEq(address(rewardTokens[1]), Addresses.TOKEN_CRV);
        assertEq(address(rewardTokens[2]), Addresses.TOKEN_CVX);
        assertEq(address(rewardTokens[3]), Addresses.TOKEN_CRVUSD);
        assertEq(
            sdtClaimable,
            IERC20(Addresses.TOKEN_SDT).balanceOf(address(gUSD))
        );
        assertEq(
            crvClaimable,
            IERC20(Addresses.TOKEN_CRV).balanceOf(address(gUSD))
        );
        assertEq(
            cvxClaimable,
            IERC20(Addresses.TOKEN_CVX).balanceOf(address(gUSD))
        );
        assertEq(
            crvUsdClaimable,
            IERC20(Addresses.TOKEN_CRVUSD).balanceOf(address(gUSD))
        );
    }
    function testProcessGovRewardsWithNothingToClaim() external {
        splitter.processRewards();
        IERC20[] memory rewardTokens = gUSD.getRewardTokens();
        assertEq(address(rewardTokens[0]), Addresses.TOKEN_SDT);
        assertEq(address(rewardTokens[1]), Addresses.TOKEN_CRV);
        assertEq(address(rewardTokens[2]), Addresses.TOKEN_CVX);
        assertEq(address(rewardTokens[3]), Addresses.TOKEN_CRVUSD);
        assertEq(0, IERC20(Addresses.TOKEN_SDT).balanceOf(address(gUSD)));
        assertEq(0, IERC20(Addresses.TOKEN_CRV).balanceOf(address(gUSD)));
        assertEq(0, IERC20(Addresses.TOKEN_CVX).balanceOf(address(gUSD)));
        assertEq(0, IERC20(Addresses.TOKEN_CRVUSD).balanceOf(address(gUSD)));
    }
    //testProcessGovRewardsWith0ToClaim

    //testProcessGovRewardsTwice
    function testProcessGovRewardsTwice() external {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(
            address(liquidityGauge)
        );
        //FIRST PROCESS
        _distributeGaugeRewards();
        skip(72000);
        uint256 sdtClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_SDT
        );
        uint256 crvClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRV
        );
        uint256 cvxClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CVX
        );
        uint256 crvUsdClaimable = _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRVUSD
        );
        splitter.processRewards();
        IERC20[] memory rewardTokens = gUSD.getRewardTokens();
        assertEq(address(rewardTokens[0]), Addresses.TOKEN_SDT);
        assertEq(address(rewardTokens[1]), Addresses.TOKEN_CRV);
        assertEq(address(rewardTokens[2]), Addresses.TOKEN_CVX);
        assertEq(address(rewardTokens[3]), Addresses.TOKEN_CRVUSD);
        assertEq(
            sdtClaimable,
            IERC20(Addresses.TOKEN_SDT).balanceOf(address(gUSD))
        );
        assertEq(
            crvClaimable,
            IERC20(Addresses.TOKEN_CRV).balanceOf(address(gUSD))
        );
        assertEq(
            cvxClaimable,
            IERC20(Addresses.TOKEN_CVX).balanceOf(address(gUSD))
        );
        assertEq(
            crvUsdClaimable,
            IERC20(Addresses.TOKEN_CRVUSD).balanceOf(address(gUSD))
        );
        //SECOND PROCESS
        _distributeGaugeRewards();
        skip(72000);
        sdtClaimable += _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_SDT
        );
        crvClaimable += _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRV
        );
        cvxClaimable += _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CVX
        );
        crvUsdClaimable += _liquidityGauge.claimable_reward(
            address(splitter),
            Addresses.TOKEN_CRVUSD
        );
        splitter.processRewards();
        assertEq(
            sdtClaimable,
            IERC20(Addresses.TOKEN_SDT).balanceOf(address(gUSD))
        );
        assertEq(
            crvClaimable,
            IERC20(Addresses.TOKEN_CRV).balanceOf(address(gUSD))
        );
        assertEq(
            cvxClaimable,
            IERC20(Addresses.TOKEN_CVX).balanceOf(address(gUSD))
        );
        assertEq(
            crvUsdClaimable,
            IERC20(Addresses.TOKEN_CRVUSD).balanceOf(address(gUSD))
        );
    }
}
