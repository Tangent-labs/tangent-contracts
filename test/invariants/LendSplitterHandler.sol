import "forge-std/Test.sol";
import "forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../src/LendRewardSplitter.sol";
import "../../src/tokens/CurveLendSplitterToken.sol";
import "../../src/interfaces/externals/ILlamaLendVault.sol";
import "../../src/interfaces/internals/ILendRewardSplitter.sol";
import "../../src/libs/Resources.sol";
import "../../src/libs/CvxConstantStructs.sol";

contract LendSplitterHandler is CommonBase, StdCheats, StdUtils {
    LendRewardSplitter private lendSplitter;
    mapping(ILlamaLendVault => uint256) public sumsBalanceOfGUSD;
    mapping(ILlamaLendVault => uint256) public sumsBalanceOfscvUSD;

    CvxConstantStructs CVX_STRUCTS;

    constructor(LendRewardSplitter _lendSplitter, CvxConstantStructs _cvxConstants) {
        lendSplitter = _lendSplitter;
        CVX_STRUCTS = _cvxConstants;
    }

    function depositCvx(
        ILlamaLendVault _llamaVault,
        uint8 inTypeNumber,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) public returns (uint256 depositAmount) {
        _llamaVault = CVX_STRUCTS.pickRandomVault();

        IgUSDCvx gUSD = lendSplitter.gUSDCvxPerLlamaVault(_llamaVault);
        IscvUSD scvUSD = lendSplitter.scvUSDCvxPerLlamaVault(_llamaVault);

        // Get the balance before the deposit
        uint256 balanceBefore;
        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
        }
        // Bound input type & amount
        inTypeNumber = 0;
        IERC20 tokenIn;
        if (inTypeNumber == 0) {
            amount = bound(amount, 3, 10_000_000 ether);
            tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        } else {
            amount = bound(amount, 10_000, 10_000_000 ether);
            tokenIn = _llamaVault;
        }

        // Get tokens & approve
        vm.startPrank(msg.sender);
        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(lendSplitter), amount);

        // Deposit
        depositAmount = lendSplitter.depositCvx(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(inTypeNumber), amount, isStableReward, doDeposit);

        // Store the balance after
        if (isStableReward) {
            sumsBalanceOfscvUSD[_llamaVault] += scvUSD.balanceOf(msg.sender) - balanceBefore;
        } else {
            sumsBalanceOfGUSD[_llamaVault] += gUSD.balanceOf(msg.sender) - balanceBefore;
        }
        // scvUSD.claimableRewards(_account);
        vm.stopPrank();
        uint256 daysToSkip = vm.randomUint();

        daysToSkip = bound(daysToSkip, 0, 7);
        skip(daysToSkip);
    }

    function withdrawCvx(ILlamaLendVault _llamaVault, uint8 outType, uint256 amount, bool isStableReward) public {
        _llamaVault = CVX_STRUCTS.pickRandomVault();
        IgUSDCvx gUSD = lendSplitter.gUSDCvxPerLlamaVault(_llamaVault);
        IscvUSD scvUSD = lendSplitter.scvUSDCvxPerLlamaVault(_llamaVault);
        // Get tokens & approve
        vm.startPrank(msg.sender);
        // If nothing has been deposited by the user before
        uint256 balanceBefore;

        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
        }

        if (balanceBefore == 0) {
            uint256 randomIsDeposit;
            randomIsDeposit = bound(randomIsDeposit, 0, 1);
            depositCvx(_llamaVault, outType, amount, isStableReward, randomIsDeposit == 1 ? true : false);
            return;
        }

        // Bound input type & amount
        outType = 0;
        IERC20 tokenIn;
        if (outType == 0) {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        } else {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = _llamaVault;
        }

        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(lendSplitter), amount);

        // Deposit
        lendSplitter.withdrawCvx(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(outType), amount, isStableReward);

        // Store the balance after
        if (isStableReward) {
            sumsBalanceOfscvUSD[_llamaVault] -= balanceBefore - scvUSD.balanceOf(msg.sender);
        } else {
            sumsBalanceOfGUSD[_llamaVault] -= balanceBefore - gUSD.balanceOf(msg.sender);
        }

        vm.stopPrank();

        uint256 daysToSkip = vm.randomUint();
        daysToSkip = bound(daysToSkip, 0, 7);
        skip(daysToSkip);
    }
}
