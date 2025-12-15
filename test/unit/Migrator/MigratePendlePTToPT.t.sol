// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigratePendlePTToPT is MarketDeploymentContext {
    IERC20Metadata public collatTokenFrom = AddrPTPendle.USDe_27_11_25;
    IERC20Metadata public collatTokenTo = AddrPTPendle.sUSDe_27_11_25;
    MarketExternalActions public marketFrom;
    MarketExternalActions public marketTo;

    uint256 constant collatIn = 100_000 ether;
    uint256 constant debtIn = 90_000 ether;

    uint256 constant collatToWithdraw = 10_000 ether;
    uint256 constant debtToRemove = 8_000 ether;
    uint256 constant debtToRepay = 10_00 ether;

    uint256[][] public swapParams;

    function setUp() public {
        marketFrom = deployBasicERC20Market(collatTokenFrom);
        marketTo = deployBasicERC20Market(collatTokenTo);

        vm.startPrank(usr1);
        deal(address(collatTokenFrom), usr1, collatIn);
        collatTokenFrom.approve(address(marketFrom), MAX_UINT);
        marketFrom.depositAndBorrow(collatIn, 50_000 ether, false);

        swapParams.push(Array.memoryUint256([uint256(0), uint256(1), uint256(9), uint256(0), uint256(0)]));
    }

    function test_migrate_one_PT_to_other_PT_with_curve_swap() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        PendlePTToSY memory pendlePTToSY = PendlePTToSY({
            market: AddrMarketPendle.USDe_27_11_25,
            pt: AddrPTPendle.USDe_27_11_25,
            sy: AddrSYPendle.USDe_27_11_25,
            yt: AddrYTPendle.USDe_27_11_25,
            underlyingOut: address(AddrClassicERC20.USDe),
            ptAmount: collatToWithdraw
        });
        CurveRouterSwapNoAmount memory curveSwapParams = encoder.createCurveRouterNoAmountStruct(
            Array.memoryAddress([address(AddrClassicERC20.USDe), address(AddrERC4626.sUSDe), address(AddrERC4626.sUSDe)]),
            swapParams,
            0,
            address(pendlePTRouter)
        );
        PendleSYToPT memory pendleSYToPT = PendleSYToPT({
            market: AddrMarketPendle.sUSDe_27_11_25,
            pt: AddrPTPendle.sUSDe_27_11_25,
            sy: AddrSYPendle.sUSDe_27_11_25,
            underlyingIn: address(AddrERC4626.sUSDe),
            minPTOut: 1,
            receiver: address(marketTo)
        });

        vm.startPrank(usr1);
        migratoor.migrate(
            migrateStruct,
            ZapMigrateStruct({
                zap: ZapStruct({router: address(pendlePTRouter), routerCall: encoder.encodeSwapPTForPT(pendlePTToSY, curveSwapParams, pendleSYToPT)}),
                minCollatToOut: 0
            })
        );
    }

    function test_migrate_one_PT_to_other_PT_without_curve_swap() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: collatToWithdraw,
            debtToRemove: debtToRemove,
            debtToRepay: debtToRepay
        });

        PendlePTToSY memory pendlePTToSY = PendlePTToSY({
            market: AddrMarketPendle.USDe_27_11_25,
            pt: AddrPTPendle.USDe_27_11_25,
            sy: AddrSYPendle.USDe_27_11_25,
            yt: AddrYTPendle.USDe_27_11_25,
            underlyingOut: address(AddrClassicERC20.USDe),
            ptAmount: collatToWithdraw
        });
        CurveRouterSwapNoAmount memory curveSwapParams = encoder.createCurveRouterNoAmountStruct(Array.memoryAddress([address(0)]), swapParams, 0, address(pendlePTRouter));
        PendleSYToPT memory pendleSYToPT = PendleSYToPT({
            market: AddrMarketPendle.sUSDe_27_11_25,
            pt: AddrPTPendle.sUSDe_27_11_25,
            sy: AddrSYPendle.sUSDe_27_11_25,
            underlyingIn: address(AddrClassicERC20.USDe),
            minPTOut: 1,
            receiver: address(marketTo)
        });

        vm.startPrank(usr1);
        migratoor.migrate(
            migrateStruct,
            ZapMigrateStruct({
                zap: ZapStruct({router: address(pendlePTRouter), routerCall: encoder.encodeSwapPTForPT(pendlePTToSY, curveSwapParams, pendleSYToPT)}),
                minCollatToOut: 0
            })
        );
    }
}
