// import {Test, console} from "forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {DeployContext} from "../DeployContext.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {SplitterToken} from "../../src/tokens/SplitterToken.sol";
// import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
// import {ILendRewardSplitter} from "../../src/interfaces/internals/LendSplitter/ILendRewardSplitter.sol";
// import {ISplitterToken} from "../../../src/interfaces/internals/LendSplitter/ISplitterToken.sol";

// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";

// contract LendRewardSplittergUsdTest is Test {
//     LendRewardSplitter splitter;
//     DeployContext testCommon;
//     gUSDSdt gUSDImplem;

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();
//         gUSDImplem = testCommon.gUSDImplem();
//     }

//     //test

//     function test_revertWhen_MintCallByUser() external {
//         address user = makeAddr("user1");
//         vm.startPrank(user);
//         vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, user));
//         gUSDImplem.mint(user, 1000 ether);
//         vm.stopPrank();
//     }

//     function test_revertWhen_BurnCallByUser() external {
//         // User 2 deposit
//         uint256 depositAmount = 50 ether;
//         IERC20 tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
//         address user2 = testCommon.getUser(2, tokenIn);
//         testCommon.deposit(depositAmount, true, true, tokenIn);
//         vm.stopPrank();

//         // User1 try to burn User2 Token
//         address user1 = makeAddr("user1");
//         vm.startPrank(user1);
//         vm.expectRevert();
//         gUSDImplem.burn(user2, 1000 ether);
//         vm.stopPrank();
//     }
// }
