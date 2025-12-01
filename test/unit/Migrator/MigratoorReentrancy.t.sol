// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract MigratoorReentrancy is MarketDeploymentContext {
    IERC20Metadata public collatTokenFrom = AddrCurveStableLP.USDC_crvUSD;
    IERC20Metadata public collatTokenTo = AddrCurveStableLP.USDT_crvUSD;
    MarketExternalActions public marketFrom;
    MarketExternalActions public marketTo;

    uint256 constant collatIn = 100_000 ether;
    uint256 constant debtIn = 90_000 ether;

    uint256 constant collatToWithdraw = 45_000 ether;
    uint256 constant debtToRemove = 42_500 ether;
    uint256 constant debtToRepay = 5_000 ether;

    bytes ZapCallErrorReentrancy;

    function setUp() public {
        marketFrom = deployConvexCurveLPMarket(collatTokenFrom);
        marketTo = deployConvexCurveLPMarket(collatTokenTo);

        vm.startPrank(usr1);

        deal(address(AddrClassicERC20.USDC), usr1, 1000 * 1e6);
        deal(address(collatTokenFrom), usr1, collatIn);
        deal(address(collatTokenTo), usr1, collatIn);

        AddrClassicERC20.USDC.approve(address(marketTo), MAX_UINT);

        collatTokenFrom.approve(address(marketFrom), MAX_UINT);
        collatTokenTo.approve(address(marketTo), MAX_UINT);
        marketFrom.depositAndBorrow(collatIn, 90_000 ether, false);

        ZapCallErrorReentrancy = abi.encodeWithSelector(
            ZappingProxy.ZapCallError.selector,
            abi.encodeWithSelector(LightReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector)
        );
    }

    function test_reenter_in_migrate() external {
        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: 0,
            debtToRemove: 3_000 ether,
            debtToRepay: 0
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({
            zap: ZapStruct({router: address(migratoor), routerCall: abi.encodeWithSelector(Migratoor.migrate.selector, migrateStruct, _getBlankZapMigrateStruct())}),
            minCollatToOut: 0
        });
        vm.expectRevert(ZapCallErrorReentrancy);
        migratoor.migrate(migrateStruct, zapCall);
    }

    function _getBlankZapMigrateStruct() internal view returns (ZapMigrateStruct memory zapCall1) {}

    function test_zapProxy_calls_deposit_marketTo() external {
        vm.startPrank(usr1);

        // Send some collatTo to the Migratoor to prepare the exploit
        collatTokenTo.transfer(address(zappingProxy), collatIn);

        // Prepare an approve of Market to with collatTo on Migratoor through the zap raw call
        zappingProxy.zapProxy(
            AddrClassicERC20.USDC,
            AddrClassicERC20.USDT,
            0,
            usr1,
            ZapStruct({router: address(collatTokenTo), routerCall: abi.encodeWithSelector(ERC20.approve.selector, marketTo, MAX_UINT)})
        );

        MigrateStruct memory migrateStruct = MigrateStruct({
            marketFrom: address(marketFrom),
            marketTo: address(marketTo),
            collatToWithdraw: 0,
            debtToRemove: 3_000 ether,
            debtToRepay: 0
        });

        ZapMigrateStruct memory zapCall = ZapMigrateStruct({
            zap: ZapStruct({router: address(marketTo), routerCall: abi.encodeWithSelector(MarketExternalActions.deposit.selector, usr1, collatIn, true)}),
            minCollatToOut: 0
        });

        // Without the ReentrancyGuardReentrantCall, the MigrateTo would have
        // 2 x what he put during the first transfer in the marketTo Collateral and we'd have misalignement between real token balances

        vm.expectRevert(ZapCallErrorReentrancy);

        migratoor.migrate(migrateStruct, zapCall);
    }
}
