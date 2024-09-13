import "forge-std/Test.sol";
import "forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../src/LendRewardSplitter.sol";
import "../../src/interfaces/externals/ILlamaLendVault.sol";
import "../../src/interfaces/internals/ILendRewardSplitter.sol";
import "../../src/libs/Resources.sol";

contract LendSplitterHandler is CommonBase, StdCheats, StdUtils {
    LendRewardSplitter private lendSplitter;
    uint256 public sumBalanceOfGUSD;
    uint256 public sumBalanceOfscvUSD;

    constructor(LendRewardSplitter _lendSplitter) {
        lendSplitter = _lendSplitter;
    }

    function depositCvx(
        ILlamaLendVault llamaVault,
        uint8 inTypeNumber,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) public returns (uint256 depositAmount) {
        llamaVault = ILlamaLendVault(AddrLlamaLendVaults.CRVUSD_CRV);
        ICurveLendSplitterToken gUSD = lendSplitter.gUSDCvxPerLlamaVault(llamaVault);
        ICurveLendSplitterToken scvUSD = lendSplitter.scvUSDCvxPerLlamaVault(llamaVault);

        // Get the balance before the deposit
        uint256 balanceBefore;
        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
        }
        // Bound input type & amount
        inTypeNumber = uint8(bound(uint256(inTypeNumber), 0, 1));
        IERC20 tokenIn;
        if (inTypeNumber == 0) {
            amount = bound(amount, 3, 10_000_000 ether);
            tokenIn = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
        } else {
            amount = bound(amount, 10_000, 10_000_000 ether);
            tokenIn = IERC20(AddrLlamaLendVaults.CRVUSD_CRV);
        }
        // Get tokens & approve
        vm.startPrank(msg.sender);
        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(lendSplitter), amount);

        // Deposit
        lendSplitter.depositCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(inTypeNumber), amount, isStableReward, doDeposit);

        // Store the balance after
        if (isStableReward) {
            sumBalanceOfscvUSD += scvUSD.balanceOf(msg.sender) - balanceBefore;
        } else {
            sumBalanceOfGUSD += gUSD.balanceOf(msg.sender) - balanceBefore;
        }

        vm.stopPrank();
    }

    function withdrawCvx(ILlamaLendVault llamaVault, uint8 outType, uint256 amount, bool isStableReward) public {
        llamaVault = ILlamaLendVault(AddrLlamaLendVaults.CRVUSD_CRV);
        ICurveLendSplitterToken gUSD = lendSplitter.gUSDCvxPerLlamaVault(llamaVault);
        ICurveLendSplitterToken scvUSD = lendSplitter.scvUSDCvxPerLlamaVault(llamaVault);
        // Get tokens & approve
        vm.startPrank(msg.sender);
        // If nothing has been deposited by the user before
        uint256 balanceBefore;
        if (balanceBefore == 0) {
            uint256 randomIsDeposit;
            randomIsDeposit = bound(randomIsDeposit, 0, 1);
            console.log("yoyoyoy", randomIsDeposit);
            depositCvx(llamaVault, outType, amount, isStableReward, randomIsDeposit == 1 ? true : false);
            return;
        }
        if (isStableReward) {
            balanceBefore = scvUSD.balanceOf(msg.sender);
        } else {
            balanceBefore = gUSD.balanceOf(msg.sender);
        }
        // Bound input type & amount
        outType = uint8(bound(uint256(outType), 0, 1));
        IERC20 tokenIn;
        if (outType == 0) {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
        } else {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = IERC20(AddrLlamaLendVaults.CRVUSD_CRV);
        }

        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(lendSplitter), amount);

        // Deposit
        lendSplitter.withdrawCvx(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(outType), amount, isStableReward);

        // Store the balance after
        if (isStableReward) {
            sumBalanceOfscvUSD += balanceBefore - scvUSD.balanceOf(msg.sender);
        } else {
            sumBalanceOfGUSD += balanceBefore - gUSD.balanceOf(msg.sender);
        }

        vm.stopPrank();
    }
}
