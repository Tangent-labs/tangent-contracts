import {Test, console} from "forge-std/Test.sol";
import {ICrvPoolPlain} from "../../src/interfaces/ICrvPoolPlain.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendRewardSplitterZapTest is Test {
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

    function test_revertWhen_addZapPoolWithZeroAddress() public {
        vm.startPrank(testCommon.owner());
        // vm.expectRevert(abi.encodeWithSelector(LendRewardSplitter.NoZeroAddress.selector, "_token"));
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NoZeroAddress(string)")), "_token"));
        splitter.addZapPool(address(0), POOL_USDC_USDCRV);
        vm.stopPrank();
    }

    function test_revertWhen_addZapPoolNotOwner() public {
        address user1 = makeAddr("random guy");
        deal(user1, 1 ether);

        vm.startPrank(user1);

        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        splitter.addZapPool(USDC, POOL_USDC_USDCRV);
        vm.stopPrank();
    }

    function test_addZapPoolUSDC() public {
        vm.startPrank(testCommon.owner());
        splitter.addZapPool(USDC, POOL_USDC_USDCRV);
        vm.stopPrank();
        assertEq(address(splitter.zapPools(USDC)), POOL_USDC_USDCRV, "USDC deposit should enabled pool != 0x0 ");
    }

    function test_disableUSDC() public {
        vm.startPrank(testCommon.owner());
        splitter.addZapPool(USDC, address(0));
        vm.stopPrank();
        assertEq(address(splitter.zapPools(USDC)), address(0), "USDC deposit should be disabled pool = 0x0 ");
    }

    function test_revertWhen_zapAndDepositWithBadMarket() public {
        testCommon.getUser(1, USDC, 2000 ether);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("MarketNotExists(address)")), USDC));
        // USDC is not a market
        splitter.zapAndDeposit(USDC, USDC, 0, 0, true, true);
    }

    function test_revertWhen_zapAndDepositWithNoAmount() public {
        testCommon.getUser(1, USDC, 2000 ether);
        vm.expectRevert();
        splitter.zapAndDeposit(address(market.stakeDaoVault), USDC, 0, 0, true, true);
    }

    function test_revertWhen_zapAndDepositWithNotAllowedToken() public {
        testCommon.getUser(1, USDC, 2000 ether);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("TokenNotAllowed()"))));
        splitter.zapAndDeposit(address(market.stakeDaoVault), USDC, 1000 ether, 0, true, true);
    }

    function test_zapAndDepositWithEth() public {
        testCommon.getUser(1, USDC, 2000 ether);
        uint256 depositedValue = splitter.zapAndDeposit{value: 1 ether}(
            address(market.stakeDaoVault),
            address(0),
            0,
            1000,
            true,
            true
        );
        console.log(depositedValue);
    }
}
