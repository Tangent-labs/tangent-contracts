// SPDX-License-Identifier: UNKNOWN
import "../../../contexts/ConvexMarketContext.sol";

contract ZapAndDepositStableConvex is ConvexMarketContext {
    // Make a fresh user.
    address user = makeAddr("user");
    function setUp() public {
        deployBaseContracts();
        setUpSingleRandomMarket();
    }
    function test_zap_and_deposit_with_eth() public {
        deal(user, 10 ether);
        vm.startPrank(user);

        // Do the zapAndDeposit
        (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
        uint256 expected = ICurveRouter(AddrGlobal.CURVE_ROUTER).get_dy(routes, swapParams, 1 ether, pools);
        splitter.zapAndDeposit{value: 1 ether}(llamaVault, 0, 0, true, false, true, routes, pools, swapParams);
        vm.stopPrank();
        assertEq(scvUSD.balanceOf(user), llamaVault.convertToShares(expected));
    }

    function _getSwapParamsForEth() internal view returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) {
        address TRI_CRV_CURVE_POOL = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
        address ETH_CURVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        routes = [ETH_CURVE_ADDRESS, TRI_CRV_CURVE_POOL, address(lendAsset), address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];

        pools = [TRI_CRV_CURVE_POOL, address(0), address(0), address(0), address(0)];

        /// @devs https://docs.curve.fi/router/CurveRouterNG/#_swap_params
        /// @devs [i => index of intoken , index of output token, swap_type, pool_type, n_coins]
        uint256[5] memory emptyParams = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
        swapParams = [[uint256(1), uint256(0), uint256(1), uint256(3), uint256(3)], emptyParams, emptyParams, emptyParams, emptyParams];
    }
}
