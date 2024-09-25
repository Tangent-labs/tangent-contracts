// import {Test, console} from "forge-std/Test.sol";
// import {ICrvPoolPlain} from "../../src/interfaces/externals/ICrvPoolPlain.sol";
// import {DeployContext} from "../DeployContext.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ICurveRouter} from "../../src/interfaces/externals/ICurveRouter.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrGlobal} from "../../src/libs/Resources.sol";
// import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {ZapAndDepositReentrancyAttack} from "./ZapAndDepositReentrancyAttack.sol";

// contract LendRewardSplitterZapTest is Test {
//     using SafeERC20 for IERC20;

//     ICurveRouter constant CURVE_ROUTER = ICurveRouter(AddrGlobal.CURVE_ROUTER);
//     IERC20 constant CRVUSD = AddrClassicERC20.TOKEN_CRVUSD;
//     IERC20 constant USDC = AddrClassicERC20.TOKEN_USDC;
//     IERC20 constant AAVE = AddrClassicERC20.TOKEN_AAVE;
//     ILlamaLendVault constant LLAMALEND_VAULT_CRV = AddrLlamaLendVaults.CRVUSD_CRV;
//     IStakeDaoVault constant SDT_VAULT_CRV = AddrSdtVaults.CRVUSD_CRV;

//     LendRewardSplitter splitter;
//     DeployContext testCommon;

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();
//     }

//     // function test_revertWhen_zapAndDepositWithBadMarket() public {
//     //     (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
//     //     testCommon.getUser(1, USDC, 2000 ether);
//     //     vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("MarketNotExists(address)")), USDC));
//     //     splitter.zapAndDeposit(ILlamaLendVault(USDC), 0, 0, false, true, true, routes, pools, swapParams); // USDC is not a market
//     // }

//     // function test_revertWhen_zapAndDepositWithNoAmount() public {
//     //     (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
//     //     testCommon.getUser(1, USDC, 2000 ether);
//     //     vm.expectRevert();
//     //     splitter.zapAndDeposit(LLAMALEND_VAULT_CRV, 0, 0, false, true, true, routes, pools, swapParams);
//     // }

//     function test_revertWhen_zapAndDepositWhenRouteNotMatchLendAsset() public {
//         testCommon.getUser(1, USDC, 2000 ether);
//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
//         routes[3] = USDC;

//         vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotLendAssetRoute(address)")), USDC));
//         splitter.zapAndDeposit{value: 1 ether}(LLAMALEND_VAULT_CRV, 0, 0, false, true, true, routes, pools, swapParams);
//     }

//     function test_zapAndDepositWithEth() public {
//         // first deposit to remove the incentive for doDeposit
//         testCommon.getUser(1, address(LLAMALEND_VAULT_CRV), 2000 ether);
//         testCommon.deposit(200 ether, true, true, address(LLAMALEND_VAULT_CRV));
//         vm.stopPrank();

//         // Make a fresh user.
//         address user2 = makeAddr("user2");
//         deal(user2, 10 ether);
//         vm.startPrank(user2);

//         // Do the zapAndDeposit
//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();
//         uint256 expected = CURVE_ROUTER.get_dy(routes, swapParams, 1 ether, pools);
//         splitter.zapAndDeposit{value: 1 ether}(LLAMALEND_VAULT_CRV, 0, 0, false, true, true, routes, pools, swapParams);
//         vm.stopPrank();
//         assertEq(testCommon.scvUSDImplem().balanceOf(user2), testCommon.curveLendVault().convertToShares(expected));
//     }

//     function test_zapAndDepositWithUsdt() public {
//         // first deposit to remove the incentive for doDeposit
//         testCommon.getUser(1, address(LLAMALEND_VAULT_CRV), 2000 ether);
//         testCommon.deposit(200 ether, true, true, address(LLAMALEND_VAULT_CRV));
//         vm.stopPrank();

//         // Make a fresh user.
//         address user2 = makeAddr("user2");
//         deal(user2, 10 ether);
//         vm.startPrank(user2);

//         // Handle the Token In.
//         address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
//         deal(USDT, user2, 10_000 ether);

//         IERC20(USDT).forceApprove(address(splitter), 100_000 ether);

//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForUsdt();

//         uint256 depositAmount = 1000 * 1e6;
//         // Do the zapAndDeposit
//         uint256 expected = CURVE_ROUTER.get_dy(routes, swapParams, depositAmount, pools);
//         splitter.zapAndDeposit(LLAMALEND_VAULT_CRV, depositAmount, (depositAmount * 99) / 100, false, true, true, routes, pools, swapParams);
//         vm.stopPrank();
//         assertEq(testCommon.scvUSDImplem().balanceOf(user2), testCommon.curveLendVault().convertToShares(expected));
//     }

//     function test_zapAndDepositWithUsdc() public {
//         // first deposit to remove the incentive for doDeposit
//         testCommon.getUser(1, address(LLAMALEND_VAULT_CRV), 2000 ether);
//         testCommon.deposit(200 ether, true, true, address(LLAMALEND_VAULT_CRV));
//         vm.stopPrank();

//         // Make a fresh user.
//         address user2 = makeAddr("user2");
//         deal(user2, 10 ether);
//         vm.startPrank(user2);

//         // Handle the Token In.
//         deal(USDC, user2, 10_000 ether);

//         IERC20(USDC).approve(address(splitter), 100_000 ether);
//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForUsdc();

//         uint256 depositAmount = 1000 * 1e6;
//         // Do the zapAndDeposit
//         uint256 expected = CURVE_ROUTER.get_dy(routes, swapParams, depositAmount, pools);
//         splitter.zapAndDeposit(LLAMALEND_VAULT_CRV, depositAmount, (depositAmount * 50) / 100, false, true, true, routes, pools, swapParams);
//         vm.stopPrank();
//         assertEq(testCommon.scvUSDImplem().balanceOf(user2), testCommon.curveLendVault().convertToShares(expected));
//     }

//     function test_revertWhen_zapAndDepositWithShiba() public {
//         // first deposit to remove the incentive for doDeposit
//         testCommon.getUser(1, address(LLAMALEND_VAULT_CRV), 2000 ether);
//         testCommon.deposit(200 ether, true, true, address(LLAMALEND_VAULT_CRV));
//         vm.stopPrank();

//         // Make a fresh user.
//         address user2 = makeAddr("user2");
//         deal(user2, 10 ether);
//         vm.startPrank(user2);

//         // Handle the Token In.
//         address SHIBA = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
//         deal(SHIBA, user2, 10_000 ether);

//         IERC20(SHIBA).approve(address(splitter), 100_000 ether);
//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForDai();

//         routes[0] = SHIBA;
//         uint256 depositAmount = 1000 ether;
//         // Do the zapAndDeposit
//         vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotAllowedInToken(address)")), SHIBA));
//         splitter.zapAndDeposit(LLAMALEND_VAULT_CRV, depositAmount, (depositAmount * 50) / 100, false, true, true, routes, pools, swapParams);
//         vm.stopPrank();
//     }

//     function test_zapAndDepositWithDai() public {
//         // first deposit to remove the incentive for doDeposit
//         testCommon.getUser(1, address(LLAMALEND_VAULT_CRV), 2000 ether);
//         testCommon.deposit(200 ether, true, true, address(LLAMALEND_VAULT_CRV));
//         vm.stopPrank();

//         // Make a fresh user.
//         address user2 = makeAddr("user2");
//         deal(user2, 10 ether);
//         vm.startPrank(user2);

//         // Handle the Token In.
//         address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
//         deal(DAI, user2, 10_000 ether);

//         IERC20(DAI).approve(address(splitter), 100_000 ether);
//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForDai();

//         uint256 depositAmount = 1000 ether;
//         // Do the zapAndDeposit
//         uint256 expected = CURVE_ROUTER.get_dy(routes, swapParams, depositAmount, pools);
//         splitter.zapAndDeposit(LLAMALEND_VAULT_CRV, depositAmount, (depositAmount * 50) / 100, false, true, true, routes, pools, swapParams);
//         vm.stopPrank();
//         assertApproxEqAbs(testCommon.scvUSDImplem().balanceOf(user2), testCommon.curveLendVault().convertToShares(expected), 1 ether);
//     }

//     function test_revertWhen_addZapTokenNotOwner() public {
//         address user1 = makeAddr("random guy");
//         deal(user1, 1 ether);

//         vm.startPrank(user1);
//         vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
//         splitter.toggleZapToken(USDC);
//         vm.stopPrank();
//     }

//     function test_addZapTokenAave() public {
//         vm.startPrank(testCommon.owner());
//         splitter.toggleZapToken(AAVE);
//         vm.stopPrank();
//         assertEq(splitter.allowedZapToken(AAVE), true, "AAVE deposit should be enabled  ");
//         assertEq(IERC20(AAVE).allowance(address(splitter), address(splitter.CURVE_ROUTER())), testCommon.MAX_UINT(), "AAVE deposit should be enabled  ");
//     }

//     function test_disableAaveZapToken() public {
//         vm.startPrank(testCommon.owner());
//         vm.expectEmit(address(splitter));
//         emit LendRewardSplitter.ToggleZapToken(AAVE, true);
//         splitter.toggleZapToken(AAVE);
//         assertEq(splitter.allowedZapToken(AAVE), true, "AAVE deposit should be enabled  ");
//         vm.expectEmit(address(splitter));
//         emit LendRewardSplitter.ToggleZapToken(AAVE, false);
//         splitter.toggleZapToken(AAVE); // second time to disable it.
//         vm.stopPrank();
//         assertEq(IERC20(AAVE).allowance(address(splitter), address(splitter.CURVE_ROUTER())), 0, "AAVE deposit should be enabled  ");
//         assertEq(splitter.allowedZapToken(AAVE), false, "AAVE deposit should be disabled  ");
//     }

//     function test_revertWhen_zapDepositReentrancy() public {
//         ZapAndDepositReentrancyAttack attacker = new ZapAndDepositReentrancyAttack(address(splitter));

//         // Fund attacker with some Ether to perform the attack.
//         vm.deal(address(attacker), 100 ether);

//         (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) = _getSwapParamsForEth();

//         // Start the attack.
//         attacker.startAttack{value: 1 ether}(LLAMALEND_VAULT_CRV, 0, 0, false, true, true, routes, pools, swapParams);
//         // expect the code has not been reenterd
//         assertEq(attacker.hasReentered(), false);
//     }

//     function _getSwapParamsForEth() internal pure returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) {
//         address TRI_CRV_CURVE_POOL = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
//         address ETH_CURVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

//         routes = [
//             ETH_CURVE_ADDRESS,
//             TRI_CRV_CURVE_POOL,
//             CRVUSD,
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             address(0)
//         ];

//         pools = [TRI_CRV_CURVE_POOL, address(0), address(0), address(0), address(0)];

//         /// @devs https://docs.curve.fi/router/CurveRouterNG/#_swap_params
//         /// @devs [i => index of intoken , index of output token, swap_type, pool_type, n_coins]
//         uint256[5] memory emptyParams = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
//         swapParams = [[uint256(1), uint256(0), uint256(1), uint256(3), uint256(3)], emptyParams, emptyParams, emptyParams, emptyParams];
//     }

//     function _getSwapParamsForUsdt() internal returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) {
//         address POOL = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4; // Stableswap
//         address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
//         vm.label(USDT, "USDT");
//         vm.label(POOL, "POOL USDT");
//         routes = [USDT, POOL, CRVUSD, address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];

//         pools = [POOL, address(0), address(0), address(0), address(0)];

//         /// @devs https://docs.curve.fi/router/CurveRouterNG/#_swap_params
//         /// @devs [i => index of intoken , index of output token, swap_type, pool_type, n_coins]
//         uint256[5] memory emptyParams = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
//         swapParams = [[uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)], emptyParams, emptyParams, emptyParams, emptyParams];
//     }

//     function _getSwapParamsForDai() internal pure returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) {
//         address t1 = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
//         address t2 = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
//         address t3 = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
//         address t4 = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
//         address t5 = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;

//         routes = [t1, t2, t3, t4, t5, address(0), address(0), address(0), address(0), address(0), address(0)];

//         address p1 = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
//         address p2 = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
//         pools = [p1, p2, address(0), address(0), address(0)];

//         uint256[5] memory emptyParams = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
//         swapParams = [
//             [uint256(0), uint256(2), uint256(1), uint256(1), uint256(3)],
//             [uint256(0), uint256(1), uint256(1), uint256(1), uint256(2)],
//             emptyParams,
//             emptyParams,
//             emptyParams
//         ];
//     }

//     function _getSwapParamsForUsdc() internal returns (address[11] memory routes, address[5] memory pools, uint256[5][5] memory swapParams) {
//         // https://etherscan.io/tx/0xf755bd270902742ae037f09e6d8fc8f007444b6d693e9965c56892e6d8069d3f

//         address POOL = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E; // Stableswap

//         vm.label(POOL, "POOL USDC");
//         vm.label(USDC, "USDC");

//         routes = [USDC, POOL, CRVUSD, address(0), address(0), address(0), address(0), address(0), address(0), address(0), address(0)];

//         pools = [POOL, address(0), address(0), address(0), address(0)];
//         (uint256 inIndex, uint256 outIndex) = _getPoolIndexes(USDC, POOL, false);

//         /// @devs https://docs.curve.fi/router/CurveRouterNG/#_swap_params
//         /// @devs [i => index of intoken , index of output token, swap_type, pool_type, n_coins]
//         uint256[5] memory emptyParams = [uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)];
//         swapParams = [[inIndex, outIndex, uint256(1), uint256(1), uint256(2)], emptyParams, emptyParams, emptyParams, emptyParams];
//     }

//     function _getPoolIndexes(address _inToken, address _pool, bool triPool) internal view returns (uint256 inIndex, uint256 outIndex) {
//         address[3] memory poolCoins;

//         poolCoins[0] = ICrvPoolPlain(_pool).coins(0);
//         poolCoins[1] = ICrvPoolPlain(_pool).coins(1);
//         if (triPool) poolCoins[2] = ICrvPoolPlain(_pool).coins(2);

//         bool foundInIndex = false;
//         bool foundOutIndex = false;

//         for (uint256 i = 0; i < 3; i++) {
//             if (poolCoins[i] == _inToken) {
//                 inIndex = i;
//                 foundInIndex = true;
//             }
//             if (poolCoins[i] == CRVUSD) {
//                 outIndex = i;
//                 foundOutIndex = true;
//             }
//         }

//         require(foundInIndex, "Input token not found in pool");
//         require(foundOutIndex, "CRV_USD not found in pool");
//     }
// }
