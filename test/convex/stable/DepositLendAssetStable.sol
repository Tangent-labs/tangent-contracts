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

contract DepositLendAssetStable is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        vm.prank(testCommon.owner());
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;
        splitter.createCvxMarkets(pids);
    }

    function test_deposit_lend_asset_and_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        ICurveLendSplitterToken scvUSD = _splitter.scvUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

        address usr = makeAddr("User");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr, 100 ether);
        vm.startPrank(usr);

        uint256 usrLendAssetBalanceBfr = IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr);

        uint256 rewardTokenCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));
        uint256 totalSupplyCvxVaultBefore = AddrCvxVaultTokens.CRVUSD_CRV.totalSupply();

        uint256 gUSDRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToShares(100 ether);

        // ACTIONS
        IERC20(address(AddrClassicERC20.TOKEN_CRVUSD)).approve(address(_splitter), 100 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, true);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(usrLendAssetBalanceBfr - IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr), 100 ether);
        // "sharesConverted" CvxVault assets created
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.totalSupply() - totalSupplyCvxVaultBefore, sharesConverted);
        // "sharesConverted" CvxVault assets received by the CvxReward
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - rewardTokenCvxVaultBfr, sharesConverted);
        // "sharesConverted" CvxReward assets received by the gUSD
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBfr, sharesConverted);

        // An amount of scvUSD is minted to the user
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted);

        // No gUSD minted for the user as we are in "stable only" mode
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0);
    }

    function test_deposit_lend_asset_and_no_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        ICurveLendSplitterToken scvUSD = _splitter.scvUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

        address usr = makeAddr("User");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr, 200 ether);
        vm.startPrank(usr);

        uint256 usrLendAssetBalanceBfr = IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr);

        uint256 gUSDCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD));
        uint256 cvxRewardVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));

        uint256 gUSDRewardTokenBalanceBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToShares(100 ether);

        // ACTIONS
        IERC20(address(AddrClassicERC20.TOKEN_CRVUSD)).approve(address(_splitter), 200 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, false);

        // VERIFY

        // 100 crvUSD sent by usr
        assertEq(usrLendAssetBalanceBfr - IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr), 100 ether);

        // "sharesConverted" CvxVault tokens received by gUSD
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDCvxVaultBfr, sharesConverted);

        // An amount of scvUSD is minted to the user equivalent to the shares he put
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted);

        // No gUSD is minted to the user
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0);

        // No CvxVault assets are given to CvxReward because not staking
        assertEq(cvxRewardVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)), 0);

        // No CvxReward assets are given to gUSD because  not staking
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, 0);
    }

    function test_deposit_lend_asset_with_doDeposit_then_deposit_without_doDeposit() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        ICurveLendSplitterToken gUSD = _splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        ICurveLendSplitterToken scvUSD = _splitter.scvUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

        address usr = makeAddr("User");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), usr, 200 ether);
        vm.startPrank(usr);

        // ACTIONS
        IERC20(address(AddrClassicERC20.TOKEN_CRVUSD)).approve(address(_splitter), 200 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, false);

        // PREPARE

        uint256 usrLendAssetBalanceBfr = IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr);

        uint256 usrCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDCvxVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD));
        uint256 cvxRewardVaultBfr = AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV));

        uint256 usrRewardTokenBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr);
        uint256 gUSDRewardTokenBalanceBfr = AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD));

        uint256 sharesConverted = AddrLlamaLendVaults.CRVUSD_CRV.convertToShares(100 ether);

        uint256 usrGUSDBalanceBfr = gUSD.balanceOf(usr);
        uint256 usrSCVUSDBalanceBfr = scvUSD.balanceOf(usr);

        // ACTIONS

        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, true, true);

        // VERIFY

        // 100 llamaLendVault assets sent by the user
        assertEq(usrLendAssetBalanceBfr - IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(usr), 100 ether);

        // "sharesConverted" cvxVault assets sent by gUSD
        assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), sharesConverted);

        // "sharesConverted" cvxVault received by cvxReward
        assertEq(gUSDCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(gUSD)), sharesConverted);

        // "2 * sharesConverted" cvxVault assets received by CvxReward ( 100 that was previously staked + 100 from the actual deposit )
        assertEq(AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(address(AddrCvxRewardTokens.CRVUSD_CRV)) - cvxRewardVaultBfr, sharesConverted * 2);

        // "2 * sharesConverted" cvxReward assets received by gUSD
        assertEq(AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(address(gUSD)) - gUSDRewardTokenBalanceBfr, sharesConverted * 2);

        // An amount of scvUSD is minted to the user equivalent to the shares he put
        assertEq(scvUSD.balanceOf(usr) - usrSCVUSDBalanceBfr, sharesConverted);

        // No gUSD is minted to the user
        assertEq(gUSD.balanceOf(usr) - usrGUSDBalanceBfr, 0);

        // No CvxReward asset is given to the user
        assertEq(usrRewardTokenBfr - AddrCvxRewardTokens.CRVUSD_CRV.balanceOf(usr), 0);
        // No CvxVault assets is given to the user
        assertEq(usrCvxVaultBfr - AddrCvxVaultTokens.CRVUSD_CRV.balanceOf(usr), 0);
    }
}
