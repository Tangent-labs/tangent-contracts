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

import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../../src/libs/Resources.sol";

contract DepositLlamaLendVaultAssetGov is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        vm.prank(testCommon.owner());
        splitter.createCvxMarket(PidCvxBooster.CRVUSD_CRV);
    }

    function test_deposit_llamaLend_vault_asset_and_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        address usr = makeAddr("User");
        deal(address(AddrLlamaLendVaults.CRVUSD_CRV), usr, 100 ether);
        vm.startPrank(usr);

        uint256 usrLlamaVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter));

        uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 rewardTokenCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));
        uint256 totalSupplyCvxVaultBefore = AddrCvxVaultTokens.CRVUSD_CRV.totalSupply();

        uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToAssets(100 ether);

        // ACTIONS
        IERC20(address(AddrLlamaLendVaults.CRVUSD_CRV)).approve(address(_splitter), 100 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, 100 ether, false, true);

        // VERIFY

        // 100 llamaLendVault transfered
        assertEq(usrLlamaVaultBalanceBfr - AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr), 100 ether);
        // 100 CvxVault assets created
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.totalSupply() - totalSupplyCvxVaultBefore, 100 ether);
        // 100 CvxVault assets received by the corresponding rewardAsset
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - rewardTokenCvxVaultBfr, 100 ether);
        // 100 eth of CvxReward assets received by the gUSD
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBfr, 100 ether);
        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);

        // No LlamalendVault are sent to the splitter
        assertEq(AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward token are given to the user
        assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
        // No CvxVault assets are given to the user
        assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);
    }

    function test_deposit_llamaLend_vault_asset_and_no_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        address usr = makeAddr("User");
        deal(address(AddrLlamaLendVaults.CRVUSD_CRV), usr, 200 ether);
        vm.startPrank(usr);

        uint256 usrLlamaVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter));

        uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD));
        uint256 cvxRewardVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));

        uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToAssets(100 ether);

        // ACTIONS
        IERC20(address(AddrLlamaLendVaults.CRVUSD_CRV)).approve(address(_splitter), 200 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, 100 ether, false, false);

        // VERIFY

        // 100 eth of llamaLendVault transfered
        assertEq(usrLlamaVaultBalanceBfr - AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr), 100 ether);

        // 100 eth of CvxVaultTokens received by the gUSD
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDCvxVaultBfr, 100 ether);

        // No CvxRewardTokens are given to the gUSD because we are not staking
        assertEq(cvxRewardVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)), 0);

        // No CvxRewardTokens are given to the gUSD because we are not staking
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, 0);
        // No LlamalendVault are sent to the splitter
        assertEq(AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
        // No CvxVault assets is given to the user
        assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);

        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);
    }

    function test_deposit_llamaLend_vault_asset_with_doDeposit_then_deposit_without_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        address usr = makeAddr("User");
        deal(address(AddrLlamaLendVaults.CRVUSD_CRV), usr, 200 ether);
        vm.startPrank(usr);

        // ACTIONS
        IERC20(address(AddrLlamaLendVaults.CRVUSD_CRV)).approve(address(_splitter), 200 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, 100 ether, false, false);

        // PREPARE

        uint256 usrLlamaVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr);
        uint256 lendSplitterVaultBalanceBfr = AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter));

        uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD));
        uint256 cvxRewardVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));

        uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToAssets(100 ether);

        // ACTIONS

        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LlamalendVaultAsset, 100 ether, false, true);

        // VERIFY

        // 100 llamaLendVault assets sent by the user
        assertEq(usrLlamaVaultBalanceBfr - AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(usr), 100 ether);

        // 100 cvxVault assets sent by gUSD
        assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), 100 ether);

        // 100 cvxVault received by cvxReward
        assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), 100 ether);

        // 200 cvxVault assets received by CvxReward ( 100 that was previously staked + 100 from the actual deposit )
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - cvxRewardVaultBfr, 200 ether);

        // 200 cvxReward assets received by gUSD
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, 200 ether);

        // An amount of gUSD equivalent to the convertToAsset is minted to the usr
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, sharesConverted);

        // No LlamalendVault are sent to the splitter
        assertEq(AddrLlamaLendVaults.CRVUSD_CRV.balanceOf(address(_splitter)) - lendSplitterVaultBalanceBfr, 0);
        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
        // No CvxVault assets is given to the user
        assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);
    }
}
