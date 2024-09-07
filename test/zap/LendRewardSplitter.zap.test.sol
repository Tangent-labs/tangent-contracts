import {Test, console} from "forge-std/Test.sol";
import {ICrvPoolPlain} from "../../src/interfaces/ICrvPoolPlain.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveRouter} from "../../src/interfaces/ICurveRouter.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterZapTest is Test {
    ICurveRouter private constant curveRouter = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);

    address POOL_USDC_USDCRV = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;
    LendRewardSplitter.MarketStruct market;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
        // Get the market.
        market = testCommon.getMarket();
    }


    function test_revertWhen_zapAndDepositWithBadMarket() public {
        (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
        testCommon.getUser(1, USDC, 2000 ether);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("MarketNotExists(address)")), USDC));
        // USDC is not a market
        splitter.zapAndDeposit(USDC, USDC, 0, 0, true, true, routes, pools, swapParams);
    }

    function test_revertWhen_zapAndDepositWithNoAmount() public {
        (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
        testCommon.getUser(1, USDC, 2000 ether);
        vm.expectRevert();
        splitter.zapAndDeposit(address(market.stakeDaoVault), USDC, 0, 0, true, true, routes, pools, swapParams);
    }


    function test_revertWhen_zapAndDepositWhenRouteNotMatchLendAsset() public {
        testCommon.getUser(1, USDC, 2000 ether);
        (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
        routes[3] = USDC;

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotLendAssetRoute(address)")), USDC));

        splitter.zapAndDeposit{value: 1 ether}(
            address(market.stakeDaoVault),
            address(0),
            0,
            0,
            true,
            true,
            routes,
            pools,
            swapParams
        );
    }

    function test_zapAndDepositWithEth() public {
        // first deposit to remove the incentive for doDeposit
        testCommon.getUser(1, Addr.CURVE_CRVUSD_CRV, 2000 ether);
        testCommon.deposit(200 ether, true, true, Addr.CURVE_CRVUSD_CRV);
        vm.stopPrank();

        // Make a fresh user.
        address user2 = makeAddr("user2");
        deal(user2, 10 ether);
        vm.startPrank(user2);

        // Do the zapAndDeposit
        (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
        uint expected = curveRouter.get_dy(routes, swapParams, 1 ether, pools);
        uint256 depositedValue = splitter.zapAndDeposit{value: 1 ether}(
            address(market.stakeDaoVault),
            address(0),
            0,
            0,
            true,
            true,
            routes,
            pools,
            swapParams
        );
        vm.stopPrank();
        console.log(depositedValue, expected);
        assertEq(testCommon.scvUSD().balanceOf(user2), testCommon.curveLendVault().convertToShares(expected));
    }

    function _getSwapParamsForEth()
        internal
        pure
        returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams)
    {
        address TRI_CRV_CURVE_POOL = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
        // address USDT_CRV_USD_CURVE_POOL = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
        address CRV_USD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
        address ETH_CURVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        routes = [
            ETH_CURVE_ADDRESS,
            TRI_CRV_CURVE_POOL,
            CRV_USD,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];

        pools = [TRI_CRV_CURVE_POOL, address(0), address(0), address(0), address(0)];

        /// @devs https://docs.curve.fi/router/CurveRouterNG/#_swap_params
        /// @devs [i, j, swap_type, pool_type, n_coins]
        swapParams = [
            [uint256(1), uint256(0), uint256(1), uint256(3), uint256(3)],
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]
        ];
    }
}
