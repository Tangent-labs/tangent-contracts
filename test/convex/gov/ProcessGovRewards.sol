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

contract ProcessGovRewards is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    gUSDCvx gUSD;
    ICurveLendSplitterToken.Fees[] feePercentage;

    struct Fees {
        uint128 processorFeePercentage;
        uint128 daoFeePercentage;
    }

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();

        vm.prank(testCommon.owner());
        uint256[] memory pids = new uint256[](1);
        pids[0] = PidCvxBooster.CRVUSD_CRV;
        splitter.createCvxMarkets(pids);
        gUSD = gUSDCvx(address(splitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV)));

        (uint128 processorFeePercentageCrv, uint128 daoFeePercentageCrv) = gUSD.fees(0);
        (uint128 processorFeePercentageCvx, uint128 daoFeePercentageCvx) = gUSD.fees(1);
        feePercentage.push(ICurveLendSplitterToken.Fees({processorFeePercentage: processorFeePercentageCrv, daoFeePercentage: daoFeePercentageCrv}));
        feePercentage.push(ICurveLendSplitterToken.Fees({processorFeePercentage: processorFeePercentageCvx, daoFeePercentage: daoFeePercentageCvx}));
    }

    function test_process_governance_rewards() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        address processor = makeAddr("Processor");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), processor, 100 ether);
        vm.startPrank(processor);

        uint256 deltaBalanceCrvSplitter = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(address(_splitter));
        uint256 deltaBalanceCvxSplitter = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(address(_splitter));

        uint256 deltaBalanceCrvProcessor = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(processor);
        uint256 deltaBalanceCvxProcessor = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(processor);

        // ACTIONS
        IERC20(AddrClassicERC20.TOKEN_CRVUSD).approve(address(_splitter), 100 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);
        skip(1 weeks);
        gUSD.processRewards();

        // VERIFY

        deltaBalanceCrvSplitter = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(address(_splitter)) - deltaBalanceCrvSplitter;
        deltaBalanceCvxSplitter = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(address(_splitter)) - deltaBalanceCvxSplitter;

        deltaBalanceCrvProcessor = IERC20(AddrClassicERC20.TOKEN_CRV).balanceOf(processor) - deltaBalanceCrvProcessor;
        deltaBalanceCvxProcessor = IERC20(AddrClassicERC20.TOKEN_CVX).balanceOf(processor) - deltaBalanceCvxProcessor;

        uint256 totalCrvProcessed = deltaBalanceCrvSplitter + deltaBalanceCrvProcessor;
        uint256 totalCvxProcessed = deltaBalanceCvxSplitter + deltaBalanceCvxProcessor;

        uint256 processorFeesCrv = (totalCrvProcessed * feePercentage[0].processorFeePercentage) / 100_000;
        uint256 processorFeesCvx = (totalCvxProcessed * feePercentage[1].processorFeePercentage) / 100_000;

        uint256 daoFeesCrv = (totalCrvProcessed * feePercentage[0].daoFeePercentage) / 100_000;
        uint256 daoFeesCvx = (totalCvxProcessed * feePercentage[1].daoFeePercentage) / 100_000;

        uint256 crvRewardsForStakers = totalCrvProcessed - processorFeesCrv - daoFeesCrv;
        uint256 cvxRewardsForStakers = totalCvxProcessed - processorFeesCvx - daoFeesCvx;

        // Verify processor received the right amount of rewards
        assertEq(processorFeesCrv, deltaBalanceCrvProcessor);
        assertEq(processorFeesCvx, deltaBalanceCvxProcessor);

        // Verify that the daoFees are stored in the daoFeeForToken mapping
        assertEq(daoFeesCrv, splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CRV)));
        assertEq(daoFeesCvx, splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CVX)));

        // Verify that the rewards for stakers are on the splitter contract.
        // It should be equal to the balance delta on the splitter minus the fees added for the DAO
        assertEq(crvRewardsForStakers, deltaBalanceCrvSplitter - splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CRV)));
        assertEq(cvxRewardsForStakers, deltaBalanceCvxSplitter - splitter.daoFeeForToken(IERC20(AddrClassicERC20.TOKEN_CVX)));

        // Splitter received more than 0 rewards
        assertGt(deltaBalanceCrvSplitter, 0);
        assertGt(deltaBalanceCvxSplitter, 0);
    }

    function test_process_governance_rewards_with_nothing_to_claim() external {
        // PREPARE
        LendRewardSplitter _splitter = splitter;
        address processor = makeAddr("Processor");
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), processor, 100 ether);
        vm.startPrank(processor);

        // ACTIONS
        IERC20(AddrClassicERC20.TOKEN_CRVUSD).approve(address(_splitter), 100 ether);
        _splitter.depositCvx(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, 100 ether, false, true);
        skip(2 weeks);
        gUSD.processRewards();
        // Ensure that second process of reward is failing because all CRV rewards have been already processed
        vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NothingToProcess.selector));
        gUSD.processRewards();
    }
}
