import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILendRewardSplitter} from "../../../src/interfaces/internals/ILendRewardSplitter.sol";
import {ICvxRewardToken} from "../../../src/interfaces/externals/ICvxRewardToken.sol";

import {ILlamaLendVault} from "../../../src/interfaces/externals/ILlamaLendVault.sol";

import {ICurveLendSplitterToken} from "../../../src/interfaces/internals/ICurveLendSplitterToken.sol";

import {CurveLendSplitterToken} from "../../../src/tokens/CurveLendSplitterToken.sol";

import {gUSDCvx} from "../../../src/tokens/convex/gUSDCvx.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../src/libs/CvxConstantStructs.sol";
import "../../../src/libs/Resources.sol";

contract WithdrawLlamaLendVaultAssetGov is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");

    CvxConstantStructs CVX_STRUCTS;
    CvxConstantStructs.CvxStruct vaultStruct;

    ILlamaLendVault llamaVault;
    uint256 pid;
    IERC20 crvGauge;
    ICvxRewardToken cvxRewardToken;
    IERC20 cvxVaultToken;
    IERC20 lendAsset;
    IgUSDCvx gUSD;
    IscvUSD scvUSD;
    address crvController;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        CVX_STRUCTS = new CvxConstantStructs(splitter);
        vaultStruct = CVX_STRUCTS.createAndGetRandomMarket();

        llamaVault = vaultStruct.llamaVault;
        pid = vaultStruct.pid;
        crvGauge = vaultStruct.crvGauge;
        crvController = vaultStruct.crvController;
        cvxRewardToken = vaultStruct.cvxRewardToken;
        cvxVaultToken = vaultStruct.cvxVaultToken;
        lendAsset = vaultStruct.lendAsset;
        gUSD = vaultStruct.gUSD;
        scvUSD = vaultStruct.scvUSD;
    }

    function test_withdraw_llamalend_vault_asset(uint256 sharesDeposited1, uint256 sharesDeposited2, uint256 withdrawnAmount1) external {
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-=
                DO 2 deposits in order to have some LLAMA LP and CVX REWARD TOKENS
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-==-=-=-==-=-=-= */
        sharesDeposited1 = bound(sharesDeposited1, 100000, 5e35);
        sharesDeposited2 = bound(sharesDeposited2, 100000, 5e35);

        // Performs a deposit with LendASset

        uint256 initialLendAssetEquivalent = CVX_STRUCTS.dealLlamaVaultAsset(llamaVault, usr1, sharesDeposited1) +
            CVX_STRUCTS.dealLlamaVaultAsset(llamaVault, usr1, sharesDeposited2);

        vm.startPrank(usr1);
        llamaVault.approve(address(splitter), UINT256_MAX);

        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, sharesDeposited1, false, true);
        splitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, sharesDeposited2, false, false);

        skip(7 days);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                WITHDRAW A PART OF THE POSITION
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // LLAMALEND
        uint256 totalSupplyLlamaLp = llamaVault.totalSupply();
        uint256 balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        uint256 balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));

        // CVX REWARD
        uint256 totalSupplyCvxReward = cvxRewardToken.totalSupply();
        uint256 balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        uint256 totalSupplyGUSD = gUSD.totalSupply();
        uint256 usrGUSDBalance = gUSD.balanceOf(usr1);

        // Verify that everythin has been removed from user
        assertEq(balOfUsr1LlamaLp, 0);

        // Bound the amount to withdraw between a small value and the balance of the user
        withdrawnAmount1 = bound(withdrawnAmount1, 2, gUSD.balanceOf(usr1));
        uint256 share = llamaVault.convertToShares(withdrawnAmount1);

        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, withdrawnAmount1, false);

        // User receives LlamaLend Asset
        assertEq(llamaVault.balanceOf(address(usr1)) - balOfUsr1LlamaLp, share);
        // gUSD is burnt from user
        assertEq(usrGUSDBalance - gUSD.balanceOf(usr1), withdrawnAmount1);
        skip(7 days);
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        WITHDRAW WHAT'S LEFT 
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // LLAMALEND
        totalSupplyLlamaLp = llamaVault.totalSupply();
        balOfGUSDLlamaLp = llamaVault.balanceOf(address(gUSD));
        balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));

        // CVX REWARD
        totalSupplyCvxReward = cvxRewardToken.totalSupply();
        balOfGUSDCvxReward = cvxRewardToken.balanceOf(address(gUSD));
        // GUSD
        totalSupplyGUSD = gUSD.totalSupply();
        usrGUSDBalance = gUSD.balanceOf(usr1);

        share = llamaVault.convertToShares(usrGUSDBalance);
        splitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usrGUSDBalance, false);

        // User receives LlamaLend Asset
        assertEq(llamaVault.balanceOf(address(usr1)) - balOfUsr1LlamaLp, share);
        // gUSD is burnt from user
        assertEq(usrGUSDBalance - gUSD.balanceOf(usr1), usrGUSDBalance);

        uint256 balOfUsr1LendAsset = lendAsset.balanceOf(usr1);
        balOfUsr1LlamaLp = llamaVault.balanceOf(address(usr1));
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    REDEEM VAULT LP TO CRVUSD  
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        llamaVault.redeem(balOfUsr1LlamaLp);

        // Verify that we withdraw approx the same amount of crvUSD
        assertApproxEqRel(lendAsset.balanceOf(usr1) - balOfUsr1LendAsset, initialLendAssetEquivalent, 1e16);

        // VERIFY

        // "shares" llamaLendVault asset received by the user
        // assertEq(LLAMALEND_VAULT_CRV.balanceOf(usr1) - usrLlamaVaultBalanceBfr, halfShares);
        // "shares" CvxVault assets burnt
        // assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), halfShares);
        // // "shares" CvxVault assets removed from the ConvexReward asset
        // assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), halfShares);
        // // "shares" CvxReward assets burnt on the gUSD
        // assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), halfShares);
        // // An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        // assertEq(gUSD.balanceOf(usr1), usrBalanceGUSD / 2);

        // /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
        //         DEPOSIT 100 CRVUS WITH AN OTHER USER
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // vm.startPrank(usr2);
        // CRVUSD.approve(address(splitter), 200 ether);
        // splitter.depositCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);

        // totalSupplyCvxVaultBefore = CVX_VAULT.totalSupply();
        // rewardTokenCvxVaultBfr = CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN));
        // gUSDRewardTokenBfr = CVX_REWARD_TOKEN.balanceOf(address(gUSD));

        // /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
        //     WITHDRAW SECOND HALF OF THE POSITION OF FIRST USER
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // vm.startPrank(usr1);
        // splitter.withdrawCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usrBalanceGUSD / 2, false);

        // // "shares" llamaLendVault asset received by the user
        // assertEq(LLAMALEND_VAULT_CRV.balanceOf(usr1), halfShares * 2);
        // // "shares" CvxVault assets burnt
        // assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), halfShares);
        // // "shares" CvxVault assets removed from the ConvexReward asset
        // assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), halfShares);
        // // "shares" CvxReward assets burnt on the gUSD
        // assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), halfShares);
        // //  An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        // assertEq(gUSD.balanceOf(usr1), 0);

        // usrLlamaVaultBalanceBfr = CRVUSD.balanceOf(usr2);
        // skip(15 weeks);

        // /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
        //     WITHDRAW THE WHOLE POSITION OF THE SECOND USER
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // vm.startPrank(usr2);
        // splitter.withdrawCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSD.balanceOf(usr2), false);

        // //  An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        // assertEq(gUSD.balanceOf(usr2), 0);

        // //  We should retrieve all the 100 crvUSD deposited, modulo the rounding from convertToShares
        // assertApproxEqAbs(CRVUSD.balanceOf(usr2) - usrLlamaVaultBalanceBfr, 100 ether, 10);
    }

    // function test_withdraw_lend_asset() external {
    //     vm.startPrank(usr2);
    //     // Performs a deposit with CRVUSD
    //     CRVUSD.approve(address(splitter), 100 ether);
    //     splitter.depositCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);
    //     // PREPARE
    //     ICurveLendSplitterToken gUSD = splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

    //     uint256 usrLendAssetBalanceBfr = CRVUSD.balanceOf(usr2);

    //     uint256 rewardTokenCvxVaultBfr = CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN));
    //     uint256 totalSupplyCvxVaultBefore = CVX_VAULT.totalSupply();

    //     uint256 gUSDRewardTokenBfr = CVX_REWARD_TOKEN.balanceOf(address(gUSD));

    //     uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr2);
    //     uint256 share = LLAMALEND_VAULT_CRV.convertToShares(gUSD.balanceOf(usr2));

    //     // ACTIONS
    //     splitter.withdrawCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usrGUSDBalanceBfr, false);

    //     // VERIFY

    //     // Approximately 100 crvusd received by the user
    //     assertApproxEqAbs(CRVUSD.balanceOf(usr2) - usrLendAssetBalanceBfr, 100 ether, 1_000);
    //     // "share" CvxVault assets burnt
    //     assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), share);

    //     // "share" CvxVault assets burnt from the Convex reward token
    //     assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), share);

    //     // "share" CvxReward assets burnt from gUSD
    //     assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), share);

    //     // Almost all cvxReward token are burnt from gUSD, what left is what has been inflated due to PPS and that should be transfered to scvUSD
    //     assertApproxEqAbs(CVX_REWARD_TOKEN.balanceOf(address(gUSD)), 0, 2_000);

    //     // All gUSD of the user have been burnt
    //     assertEq(usrGUSDBalanceBfr - gUSD.balanceOf(usr2), usrGUSDBalanceBfr);
    // }
}
