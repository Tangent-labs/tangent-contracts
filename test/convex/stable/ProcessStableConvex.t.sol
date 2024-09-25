// import {Test, console} from "forge-std/Test.sol";
// import {DeployContext} from "../../DeployContext.sol";
// import {LendRewardSplitter} from "../../../src/LendRewardSplitter.sol";
// import {IStakeDaoVault} from "../../../src/interfaces/externals/IStakeDaoVault.sol";
// import {ILendRewardSplitter} from "../../../src/interfaces/internals/ILendRewardSplitter.sol";
// import {ICvxRewardToken} from "../../../src/interfaces/externals/ICvxRewardToken.sol";
// import {ICurveLendSplitterToken} from "../../../src/interfaces/internals/ICurveLendSplitterToken.sol";

// import {CurveLendSplitterToken} from "../../../src/tokens/CurveLendSplitterToken.sol";

// import {gUSDCvx} from "../../../src/tokens/convex/gUSDCvx.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../../src/libs/Resources.sol";
// import "../ConvexMarketContext.sol";
// contract ProcessStableConvex is ConvexMarketContext {
//     CvxConstantStructs CVX_STRUCTS;
//     CvxConstantStructs.CvxStruct vaultStruct;

//     ILlamaLendVault llamaVault;
//     uint256 pid;
//     IERC20 crvGauge;
//     ICvxRewardToken cvxRewardToken;
//     IERC20 cvxVaultToken;
//     IERC20 lendAsset;
//     IgUSDCvx gUSD;
//     IscvUSD scvUSD;

//     function setUp() public {
//         deployBaseContracts();

//         CVX_STRUCTS = new CvxConstantStructs(splitter);
//         vaultStruct = CVX_STRUCTS.createAndGetRandomMarket();

//         llamaVault = vaultStruct.llamaVault;
//         pid = vaultStruct.pid;
//         crvGauge = vaultStruct.crvGauge;
//         cvxRewardToken = vaultStruct.cvxRewardToken;
//         cvxVaultToken = vaultStruct.cvxVaultToken;
//         lendAsset = vaultStruct.lendAsset;
//         gUSD = vaultStruct.gUSD;
//         scvUSD = vaultStruct.scvUSD;
//     }

//     function test_dada() external {
//         uint256 amount = 100 ether;
//         address user = makeAddr("USER");
//         deal(address(AddrClassicERC20.TOKEN_CRVUSD), user, amount * 1000);
//         vm.startPrank(user);
//         AddrClassicERC20.TOKEN_CRVUSD.approve(address(splitter), type(uint256).max);

//         // Deposit for stable rewards
//         splitter.depositCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, true, true);

//         // Deposit for governance rewards
//         splitter.depositCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amount, false, true);

//         skip(100 days);

//         vaultStruct.scvUSD.processRewards();
//         vaultStruct.gUSD.processRewards();

//         skip(7 days);

//         splitter.claimSimple(address(vaultStruct.scvUSD), user);
//         splitter.claimSimple(address(vaultStruct.gUSD), user);

//         splitter.withdrawCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, vaultStruct.gUSD.balanceOf(user), false);
//         splitter.withdrawCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, vaultStruct.scvUSD.balanceOf(user), true);
//     }
// }
