import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILendRewardSplitter} from "../../../src/interfaces/internals/ILendRewardSplitter.sol";
import {ICvxRewardToken} from "../../../src/interfaces/externals/ICvxRewardToken.sol";
import {ICurveLendSplitterToken} from "../../../src/interfaces/internals/ICurveLendSplitterToken.sol";

import {CurveLendSplitterToken} from "../../../src/tokens/CurveLendSplitterToken.sol";

import {gUSDCvx} from "../../../src/tokens/convex/gUSDCvx.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../src/libs/CvxConstantStructs.sol";


import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../../src/libs/Resources.sol";

contract DepositLendAssetGov is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    CvxConstantStructs CVX_STRUCTS;
    CvxConstantStructs.CvxStruct vaultStruct;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        CVX_STRUCTS = new CvxConstantStructs(splitter);
        vaultStruct = CVX_STRUCTS.createAndGetRandomMarket();
    }

    // function test_deposit_lend_asset_and_doDeposit(uint104 amountIn) external {
    //     vm.assume(amountIn > 1);
    //     // PREPARE
    //     LendRewardSplitter _splitter = splitter;
    //     ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
    //     address usr = makeAddr("User");
    //     deal(address(CRVUSD), usr, amountIn);
    //     vm.startPrank(usr);

    //     uint256 usrLendAssetBalanceBfr = CRVUSD.balanceOf(usr);
    //     // uint256 llamaLendVaultLendAssetBalanceBfr = IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(address(AddrLlamaLendVaults.CRVUSD_CRV));

    //     uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
    //     uint256 rewardTokenCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));
    //     uint256 totalSupplyCvxVaultBefore = AddrCvxVaultTokens.CRVUSD_CRV.totalSupply();

    //     uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
    //     uint256 gUSDRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

    //     uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

    //     uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToShares(amountIn);

    //     // ACTIONS
    //     CRVUSD.approve(address(_splitter), amountIn);
    //     _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, true);

    //     // VERIFY

    //     // 100 crvUSD sent by usr
    //     assertEq(usrLendAssetBalanceBfr - IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr), amountIn);
    //     // "sharesConverted" CvxVault assets created
    //     assertEq(AddrCvxVaultTokens.CRVUSD_CRV.totalSupply() - totalSupplyCvxVaultBefore, sharesConverted);
    //     // "sharesConverted" CvxVault assets received by the CvxReward
    //     assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - rewardTokenCvxVaultBfr, sharesConverted);
    //     // "sharesConverted" CvxReward assets received by the gUSD
    //     assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBfr, sharesConverted);
    //     // An amount of gUSD equivalent to the convertToAsset is minted to the usr
    //     assertApproxEqAbs(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, amountIn, 1);

    //     // No CvxReward token are given to the user
    //     assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
    //     // No CvxVault assets are given to the user
    //     assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);
    // }

    function test_deposit_lend_asset_and_no_doDeposit() external {
        // PREPARE
        uint256 amount = 100 ether;
        LendRewardSplitter _splitter = splitter;
        address usr = makeAddr("User");
        deal(address(vaultStruct.lendAsset), usr, 200 ether);
        vm.startPrank(usr);

        uint256 usrLendAssetBalanceBfr = vaultStruct.lendAsset.balanceOf(usr);

        uint256 usrLlamaLpBfr = vaultStruct.llamaVault.balanceOf(usr);
        uint256 gUSDLlamaLpBfr = vaultStruct.llamaVault.balanceOf(address(vaultStruct.gUSD));

        uint256 usrRewardTokenBfr = vaultStruct.cvxRewardToken.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = vaultStruct.cvxRewardToken.balanceOf(address(vaultStruct.gUSD));

        uint256 usrGUSDBalanceBfr = vaultStruct.gUSD.balanceOf(usr);
        uint256 sharesConverted = vaultStruct.llamaVault.convertToShares(100 ether);

        // ACTIONS
        vaultStruct.lendAsset.approve(address(_splitter), 200 ether);
        _splitter.depositCvx(vaultStruct.llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, false);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(usrLendAssetBalanceBfr - vaultStruct.lendAsset.balanceOf(usr), 100 ether);

        // Shares of LlamaLP sent to gUSD
        assertEq(vaultStruct.llamaVault.balanceOf(address(vaultStruct.gUSD)) - gUSDLlamaLpBfr, sharesConverted);

        // An amount of gUSD almost equals to 100 is minted to the user
        assertApproxEqAbs(vaultStruct.gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 100 ether, 1);

        // No CvxRewardTokens are given to the gUSD because we are not staking
        assertEq(vaultStruct.cvxRewardToken.balanceOf(address(vaultStruct.gUSD)) - gUSDRewardTokenBalanceBfr, 0);
    }

    // function test_deposit_lend_asset_with_doDeposit_then_deposit_without_doDeposit() external {
    //     // PREPARE
    //     LendRewardSplitter _splitter = splitter;
    //     ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
    //     address usr = makeAddr("User");
    //     deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr, 200 ether);
    //     vm.startPrank(usr);

    //     // ACTIONS
    //     IERC20(address(AddrClassicERC20.TOKEN_CRVUSD)).approve(address(_splitter), 200 ether);
    //     _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, false);

    //     // PREPARE

    //     uint256 usrLendAssetBalanceBfr = IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr);

    //     uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
    //     uint256 gUSDCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD));
    //     uint256 cvxRewardVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));

    //     uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
    //     uint256 gUSDRewardTokenBalanceBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

    //     uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToShares(100 ether);

    //     // ACTIONS

    //     _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);

    //     // VERIFY

    //     // 100 llamaLendVault assets sent by the user
    //     assertEq(usrLendAssetBalanceBfr - IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr), 100 ether);

    //     // "sharesConverted" cvxVault assets sent by gUSD
    //     assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), sharesConverted);

    //     // "sharesConverted" cvxVault received by cvxReward
    //     assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), sharesConverted);

    //     // "2 * sharesConverted" cvxVault assets received by CvxReward ( 100 that was previously staked + 100 from the actual deposit )
    //     assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - cvxRewardVaultBfr, sharesConverted * 2);

    //     // "2 * sharesConverted" cvxReward assets received by gUSD
    //     assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, sharesConverted * 2);

    //     // No CvxReward asset is given to the user
    //     assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
    //     // No CvxVault assets is given to the user
    //     assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);
    // }
}
