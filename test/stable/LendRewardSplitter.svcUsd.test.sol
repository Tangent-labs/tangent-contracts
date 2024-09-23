// import {Test, console} from "forge-std/Test.sol";
// import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";
// import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";

// contract LendRewardSplitterScvUsdTest is Test {
//     LendRewardSplitter splitter;
//     LendRewardSplitterTestCommon testCommon;
//     scvUSDSdt scvUSDImplem;

//     function setUp() public {
//         testCommon = new LendRewardSplitterTestCommon();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();
//         scvUSDImplem = testCommon.scvUSDImplem();
//     }

//     function test_revertWhen_MintCallByUser() external {
//         address user = makeAddr("user1");
//         vm.startPrank(user);
//         vm.expectRevert();
//         scvUSDImplem.mint(user, 1000 ether);
//         vm.stopPrank();
//     }

//     function test_revertWhen_BurnCallByUser() external {
//         // User 2 deposit
//         uint256 depositAmount = 50 ether;
//         address tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
//         address user2 = testCommon.getUser(2, tokenIn);
//         testCommon.deposit(depositAmount, true, true, tokenIn);
//         vm.stopPrank();

//         // User1 try to burn User2 Token
//         address user1 = makeAddr("user1");
//         vm.startPrank(user1);
//         vm.expectRevert();
//         scvUSDImplem.burn(user2, 1000 ether);
//         vm.stopPrank();
//     }
// }
