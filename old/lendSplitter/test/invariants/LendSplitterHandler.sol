import "forge-std/Test.sol";
import "forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../../src/LendSplitter/LendRewardSplitter.sol";
import "../../../src/LendSplitter/tokens/SplitterToken.sol";
import "../../../src/interfaces/externals/LlamaLend/ILlamaVault.sol";
import "../../../src/interfaces/internals/LendSplitter/ILendRewardSplitter.sol";
import "../../../src/libs/Resources/ResourcesGlobal.sol";
import "../../../src/libs/Resources/ResourcesYieldSplitter.sol";
import "../contexts/ConvexMarketContext.sol";
import "../contexts/LendingContext.sol";
contract LendSplitterHandler is CommonBase, StdCheats, StdUtils, LendingContext {
    LendRewardSplitter private splitter;
    mapping(ILlamaVault => uint256) public sumsBalanceOfGUSD;
    mapping(ILlamaVault => uint256) public sumsBalanceOfscvUSD;

    ConvexMarketContext CVX_STRUCTS;

    constructor(LendRewardSplitter _splitter, ConvexMarketContext _invariantTestFile) {
        splitter = _splitter;
        CVX_STRUCTS = _invariantTestFile;
    }

    function depositCvx(
        ILlamaVault _llamaVault,
        uint256 inTypeNumber,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) public returns (uint256 depositAmount) {
        _llamaVault = CVX_STRUCTS.pickRandomVault();
        // Randomly creates or repay a loan
        createLoanOrRepay(_llamaVault);

        ConvexMarketContext.CvxStruct memory actualStruct = CVX_STRUCTS.getStruct(_llamaVault);

        IgUSDCvx gUSD = actualStruct.gUSD;
        IscvUSD scvUSD = actualStruct.scvUSD;

        // Get the balance before the deposit
        uint256 balanceBefore;
        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
        }
        // Bound input type & amount
        inTypeNumber = bound(inTypeNumber, 0, 1);
        IERC20 tokenIn;
        if (inTypeNumber == 0) {
            amount = bound(amount, 1e16, 10_000_000 ether);
            tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
            deal(address(tokenIn), msg.sender, amount);
        } else {
            amount = bound(amount, 1e20, 10_000_000 ether);
            tokenIn = _llamaVault;
            CVX_STRUCTS.dealLlamaVaultAsset(_llamaVault, msg.sender, amount);
        }

        // Get tokens & approve
        vm.startPrank(msg.sender);

        tokenIn.approve(address(splitter), amount);

        // Deposit

        // Store the balance after
        if (isStableReward) {
            depositAmount = splitter.depositSCVUSD(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(inTypeNumber), amount, false, doDeposit);
            sumsBalanceOfscvUSD[_llamaVault] += scvUSD.balanceOf(msg.sender) - balanceBefore;
        } else {
            depositAmount = splitter.depositGUSD(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(inTypeNumber), amount, doDeposit);
            sumsBalanceOfGUSD[_llamaVault] += gUSD.balanceOf(msg.sender) - balanceBefore;
        }
        // scvUSD.claimableRewards(_account);
        vm.stopPrank();

        skip(bound(vm.randomUint(), 0, 24) * 3_600);
    }

    function withdrawCvx(ILlamaVault _llamaVault, uint256 outType, uint256 amount, bool isStableReward, bool isDeposited) public {
        _llamaVault = CVX_STRUCTS.pickRandomVault();
        ConvexMarketContext.CvxStruct memory actualStruct = CVX_STRUCTS.getStruct(_llamaVault);
        // Randomly creates or repay a loan
        createLoanOrRepay(_llamaVault);

        IgUSDCvx gUSD = splitter.gUSDPerLlamaVault(_llamaVault);
        IscvUSD scvUSD = splitter.scvUSDPerLlamaVault(_llamaVault);
        // Get tokens & approve
        vm.startPrank(msg.sender);
        // If nothing has been deposited by the user before
        uint256 balanceBefore;

        uint256 amountLendAssetInController = actualStruct.lendAsset.balanceOf(address(actualStruct.crvController));
        uint256 maxWithdrawable;
        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
            // In case utilisation rate is too high
            if (_llamaVault.convertToAssets(balanceBefore) > amountLendAssetInController) {
                maxWithdrawable = _llamaVault.convertToShares(amountLendAssetInController);
            } else {
                maxWithdrawable = balanceBefore;
            }
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
            // In case utilisation rate is too high
            if (balanceBefore > amountLendAssetInController) {
                maxWithdrawable = amountLendAssetInController;
            } else {
                maxWithdrawable = balanceBefore;
            }
        }

        if (balanceBefore == 0) {
            depositCvx(_llamaVault, outType, amount, isStableReward, isDeposited);
            return;
        }

        // Bound input type & amount
        outType = bound(outType, 0, 1);

        amount = bound(amount, 1, maxWithdrawable);

        // Store the balance after
        if (isStableReward) {
            splitter.withdrawSCVUSD(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(outType), amount, false);
            sumsBalanceOfscvUSD[_llamaVault] -= balanceBefore - scvUSD.balanceOf(msg.sender);
        } else {
            splitter.withdrawGUSD(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(outType), amount);
            sumsBalanceOfGUSD[_llamaVault] -= balanceBefore - gUSD.balanceOf(msg.sender);
        }

        vm.stopPrank();

        skip(bound(vm.randomUint(), 0, 24) * 3_600);
    }
}
