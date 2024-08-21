import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterTokenStream} from "../../src/tokens/CurveLendSplitterTokenStream.sol";

contract LendRewardSplitterScvUsdTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;
    CurveLendSplitterTokenStream scvUSD;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
        scvUSD = testCommon.scvUSD();
    }

    function test_revertWhen_MintCallByUser() external {
        address user = makeAddr("user1");
        vm.startPrank(user);
        vm.expectRevert();
        scvUSD.mint(user, 1000 ether);
        vm.stopPrank();
    }

    function test_revertWhen_BurnCallByUser() external {
        // User 2 deposit
        uint256 depositAmount = 50 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user2 = testCommon.getUser(2, tokenIn);
        testCommon.deposit(depositAmount, true, true, tokenIn);
        vm.stopPrank();

        // User1 try to burn User2 Token
        address user1 = makeAddr("user1");
        vm.startPrank(user1);
        vm.expectRevert();
        scvUSD.burn(user2, 1000 ether);
        vm.stopPrank();
    }
}
