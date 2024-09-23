import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../../src/interfaces/internals/ICurveLendSplitterToken.sol";

import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";

contract LendRewardSplittergUsdTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;
    gUSDSdt gUSDImplem;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
        gUSDImplem = testCommon.gUSDImplem();
    }

    //test

    function test_revertWhen_MintCallByUser() external {
        address user = makeAddr("user1");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NotLendRewardSplitter.selector, user));
        gUSDImplem.mint(user, 1000 ether);
        vm.stopPrank();
    }

    function test_revertWhen_BurnCallByUser() external {
        // User 2 deposit
        uint256 depositAmount = 50 ether;
        IERC20 tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        address user2 = testCommon.getUser(2, tokenIn);
        testCommon.deposit(depositAmount, true, true, tokenIn);
        vm.stopPrank();

        // User1 try to burn User2 Token
        address user1 = makeAddr("user1");
        vm.startPrank(user1);
        vm.expectRevert();
        gUSDImplem.burn(user2, 1000 ether);
        vm.stopPrank();
    }
}
