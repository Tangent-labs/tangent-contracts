import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterStableProcessTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_processStableRewards() external {
        uint256 depositAmount = 10_000 ether;
        address tokenIn = Addr.CURVE_CRVUSD_CRV;
        address user1 = testCommon.getUser(1, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, true, true, tokenIn);
        vm.stopPrank();
        address user2 = testCommon.getUser(2, tokenIn, depositAmount);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        vm.stopPrank();
        skip(200 days);

        address user3 = testCommon.getUser(3, tokenIn);
        console.log("testCommon.getMarket() before");
        LendRewardSplitter.MarketStruct memory market = testCommon.getMarket();
        console.log("testCommon.getMarket() after");
        market.scvUSD.processStableRewards(address(market.stakeDaoVault));

        assertEq(true, true);
    }
}
