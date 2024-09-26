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
import "../../test/convex/ConvexMarketContext.sol";

contract LendSplitterHandler is CommonBase, StdCheats, StdUtils {
    LendRewardSplitter private splitter;
    mapping(ILlamaLendVault => uint256) public sumsBalanceOfGUSD;
    mapping(ILlamaLendVault => uint256) public sumsBalanceOfscvUSD;

    ConvexMarketContext CVX_STRUCTS;

    constructor(LendRewardSplitter _splitter, ConvexMarketContext _invariantTestFile) {
        splitter = _splitter;
        CVX_STRUCTS = _invariantTestFile;
    }

    function depositCvx(
        ILlamaLendVault _llamaVault,
        uint256 inTypeNumber,
        uint256 amount,
        bool isStableReward,
        bool doDeposit
    ) public returns (uint256 depositAmount) {
        _llamaVault = CVX_STRUCTS.pickRandomVault();

        IgUSDCvx gUSD = splitter.gUSDCvxPerLlamaVault(_llamaVault);
        IscvUSD scvUSD = splitter.scvUSDCvxPerLlamaVault(_llamaVault);

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
        } else {
            amount = bound(amount, 1e20, 10_000_000 ether);
            tokenIn = _llamaVault;
        }

        // Get tokens & approve
        vm.startPrank(msg.sender);
        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(splitter), amount);

        // Deposit
        depositAmount = splitter.depositCvx(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(inTypeNumber), amount, isStableReward, doDeposit);

        // Store the balance after
        if (isStableReward) {
            sumsBalanceOfscvUSD[_llamaVault] += scvUSD.balanceOf(msg.sender) - balanceBefore;
        } else {
            sumsBalanceOfGUSD[_llamaVault] += gUSD.balanceOf(msg.sender) - balanceBefore;
        }
        // scvUSD.claimableRewards(_account);
        vm.stopPrank();

        skip(bound(vm.randomUint(), 0, 24) * 3_600);
    }

    function withdrawCvx(ILlamaLendVault _llamaVault, uint256 outType, uint256 amount, bool isStableReward, bool isDeposited) public {
        _llamaVault = CVX_STRUCTS.pickRandomVault();
        IgUSDCvx gUSD = splitter.gUSDCvxPerLlamaVault(_llamaVault);
        IscvUSD scvUSD = splitter.scvUSDCvxPerLlamaVault(_llamaVault);
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
            depositCvx(_llamaVault, outType, amount, isStableReward, isDeposited);
            return;
        }

        // Bound input type & amount
        outType = bound(outType, 0, 1);

        IERC20 tokenIn;
        if (outType == 0) {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        } else {
            amount = bound(amount, 1, balanceBefore);
            tokenIn = _llamaVault;
        }

        deal(address(tokenIn), msg.sender, amount);
        tokenIn.approve(address(splitter), amount);

        // Deposit
        splitter.withdrawCvx(_llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE(outType), amount, isStableReward);

        // Store the balance after
        if (isStableReward) {
            sumsBalanceOfscvUSD[_llamaVault] -= balanceBefore - scvUSD.balanceOf(msg.sender);
        } else {
            sumsBalanceOfGUSD[_llamaVault] -= balanceBefore - gUSD.balanceOf(msg.sender);
        }

        vm.stopPrank();

        skip(bound(vm.randomUint(), 0, 24) * 3_600);
    }
}
