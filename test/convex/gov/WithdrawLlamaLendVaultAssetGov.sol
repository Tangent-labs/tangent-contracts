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

import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../../src/libs/Resources.sol";

contract WithdrawLlamaLendVaultAssetGov is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");

    IERC20 constant CRVUSD = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
    ILlamaLendVault constant LLAMALEND_VAULT_CRV = AddrLlamaLendVaults.CRVUSD_CRV;
    IERC20 constant CVX_VAULT = AddrCvxVaultTokens.CRVUSD_CRV;
    ICvxRewardToken constant CVX_REWARD_TOKEN = AddrCvxRewardTokens.CRVUSD_CRV;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        vm.prank(testCommon.owner());
        // Create a market
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;
        splitter.createCvxMarkets(pids);

        deal(address(LLAMALEND_VAULT_CRV), usr1, 100 ether);
        deal(address(LLAMALEND_VAULT_CRV), usr2, 100 ether);
        deal(address(CRVUSD), usr2, 100 ether);
    }

    function test_withdraw_llamalend_vault_asset() external {
        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                DO A FIRST DEPOSIT WITH LLAMALEND VAULT LP 
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
        vm.startPrank(usr1);
        // Performs a deposit with LendASset
        LLAMALEND_VAULT_CRV.approve(address(splitter), 200 ether);

        splitter.depositCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, 100 ether, false, true);
        // PREPARE
        ICurveLendSplitterToken gUSD = splitter.gUSDCvxPerLlamaVault(LLAMALEND_VAULT_CRV);

        uint256 usrLlamaVaultBalanceBfr = IERC20(LLAMALEND_VAULT_CRV).balanceOf(usr1);

        uint256 rewardTokenCvxVaultBfr = CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN));
        uint256 totalSupplyCvxVaultBefore = CVX_VAULT.totalSupply();

        uint256 gUSDRewardTokenBfr = CVX_REWARD_TOKEN.balanceOf(address(gUSD));

        uint256 usrBalanceGUSD = gUSD.balanceOf(usr1);

        uint256 halfShares = LLAMALEND_VAULT_CRV.convertToShares(gUSD.balanceOf(usr1) / 2);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                WITHDRAW HALF OF THE POSITION in LLAMALEND LP 
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        splitter.withdrawCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usrBalanceGUSD / 2, false);

        // VERIFY

        // "shares" llamaLendVault asset received by the user
        assertEq(LLAMALEND_VAULT_CRV.balanceOf(usr1) - usrLlamaVaultBalanceBfr, halfShares);
        // "shares" CvxVault assets burnt
        assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), halfShares);
        // "shares" CvxVault assets removed from the ConvexReward asset
        assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), halfShares);
        // "shares" CvxReward assets burnt on the gUSD
        assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), halfShares);
        // An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        assertEq(gUSD.balanceOf(usr1), usrBalanceGUSD / 2);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                DEPOSIT 100 CRVUS WITH AN OTHER USER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr2);
        CRVUSD.approve(address(splitter), 200 ether);
        splitter.depositCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);

        totalSupplyCvxVaultBefore = CVX_VAULT.totalSupply();
        rewardTokenCvxVaultBfr = CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN));
        gUSDRewardTokenBfr = CVX_REWARD_TOKEN.balanceOf(address(gUSD));

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
            WITHDRAW SECOND HALF OF THE POSITION OF FIRST USER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr1);
        splitter.withdrawCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, usrBalanceGUSD / 2, false);

        // "shares" llamaLendVault asset received by the user
        assertEq(LLAMALEND_VAULT_CRV.balanceOf(usr1), halfShares * 2);
        // "shares" CvxVault assets burnt
        assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), halfShares);
        // "shares" CvxVault assets removed from the ConvexReward asset
        assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), halfShares);
        // "shares" CvxReward assets burnt on the gUSD
        assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), halfShares);
        //  An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        assertEq(gUSD.balanceOf(usr1), 0);

        usrLlamaVaultBalanceBfr = CRVUSD.balanceOf(usr2);
        skip(15 weeks);

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
            WITHDRAW THE WHOLE POSITION OF THE SECOND USER
        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        vm.startPrank(usr2);
        splitter.withdrawCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSD.balanceOf(usr2), false);

        //  An amount of gUSD equivalent to the convertToAsset is minted to the usr1
        assertEq(gUSD.balanceOf(usr2), 0);

        //  We should retrieve all the 100 crvUSD deposited, modulo the rounding from convertToShares
        assertApproxEqAbs(CRVUSD.balanceOf(usr2) - usrLlamaVaultBalanceBfr, 100 ether, 10);
    }

    function test_withdraw_lend_asset() external {
        vm.startPrank(usr2);
        // Performs a deposit with CRVUSD
        CRVUSD.approve(address(splitter), 100 ether);
        splitter.depositCvx(LLAMALEND_VAULT_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);
        // PREPARE
        ICurveLendSplitterToken gUSD = splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

        uint256 usrLendAssetBalanceBfr = CRVUSD.balanceOf(usr2);

        uint256 rewardTokenCvxVaultBfr = CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN));
        uint256 totalSupplyCvxVaultBefore = CVX_VAULT.totalSupply();

        uint256 gUSDRewardTokenBfr = CVX_REWARD_TOKEN.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr2);
        uint256 share = LLAMALEND_VAULT_CRV.convertToShares(gUSD.balanceOf(usr2));

        // ACTIONS
        splitter.withdrawCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, usrGUSDBalanceBfr, false);

        // VERIFY

        // Approximately 100 crvusd received by the user
        assertApproxEqAbs(CRVUSD.balanceOf(usr2) - usrLendAssetBalanceBfr, 100 ether, 1_000);
        // "share" CvxVault assets burnt
        assertEq(totalSupplyCvxVaultBefore - CVX_VAULT.totalSupply(), share);

        // "share" CvxVault assets burnt from the Convex reward token
        assertEq(rewardTokenCvxVaultBfr - CVX_VAULT.balanceOf(address(CVX_REWARD_TOKEN)), share);

        // "share" CvxReward assets burnt from gUSD
        assertEq(gUSDRewardTokenBfr - CVX_REWARD_TOKEN.balanceOf(address(gUSD)), share);

        // Almost all cvxReward token are burnt from gUSD, what left is what has been inflated due to PPS and that should be transfered to scvUSD
        assertApproxEqAbs(CVX_REWARD_TOKEN.balanceOf(address(gUSD)), 0, 2_000);

        // All gUSD of the user have been burnt
        assertEq(usrGUSDBalanceBfr - gUSD.balanceOf(usr2), usrGUSDBalanceBfr);
    }
}
