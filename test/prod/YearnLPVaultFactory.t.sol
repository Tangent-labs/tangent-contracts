// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployYearnLPVaultFactory} from "script/DeployYearnLPVaultFactory.s.sol";
import {YearnCurveLPVaultFactory} from "src/USG/Utilities/YearnCurveLPVaultFactory.sol";
import {IYearnVaultFactory} from "src/interfaces/externals/YearnFi/IYearnVaultFactory.sol";
import {IYearnRoleManager} from "src/interfaces/externals/YearnFi/IYearnRoleManager.sol";
import {IRouterV2} from "src/interfaces/externals/YearnFi/IRouterV2.sol";
import {IYearnV3Vault} from "src/interfaces/externals/YearnFi/IYearnV3Vault.sol";

contract YearnLPVaultFactoryTest is Test {
    address constant LP = 0x97BA10115da528c113462EDE9C20D7adc806D93f; // USG-USDC
    address constant V2 = 0x2FEE733d8939343615a8627BC29f95390a161e74;
    IYearnRoleManager constant RM = IYearnRoleManager(0xb3bd6B2E61753C311EFbCF0111f75D29706D9a41);
    address constant BRAIN = 0x16388463d60FFE0661Cf7F1f31a7D658aC790ff7;

    function test_factory() external {
        vm.createSelectFork("mainnet");
        YearnCurveLPVaultFactory factory = new DeployYearnLPVaultFactory().run();
        assertEq(factory.owner(), BRAIN);
        address keeper = RM.getKeeper();

        // permissionless deploy
        vm.prank(makeAddr("anyone"));
        (IYearnV3Vault vault, IRouterV2 strategy) = factory.deploy(LP, "Curve USG-USDC yVault", "yvCurve-USG-USDC");
        assertEq(factory.vaults(LP), address(vault));

        // vault config
        assertEq(vault.asset(), LP);
        assertEq(vault.deposit_limit(), 1e29);
        assertEq(vault.profitMaxUnlockTime(), 4 days);
        assertTrue(vault.auto_allocate());
        address[] memory queue = vault.get_default_queue();
        assertEq(queue.length, 1);
        assertEq(queue[0], address(strategy));
        (,,, uint256 maxDebt) = IVaultStrategies(address(vault)).strategies(address(strategy));
        assertEq(maxDebt, 1e29);

        // vault handoff: factory keeps nothing, RoleManager is pending role manager
        assertEq(vault.roles(address(factory)), 0);
        assertEq(vault.future_role_manager(), address(RM));

        // strategy config: Yearn roles from the RoleManager
        assertEq(strategy.V2_VAULT(), V2);
        assertTrue(strategy.allowed(address(vault)));
        assertEq(strategy.performanceFee(), 0);
        assertEq(strategy.profitMaxUnlockTime(), 0);
        assertEq(strategy.keeper(), keeper);
        assertEq(strategy.emergencyAdmin(), BRAIN);
        assertEq(strategy.performanceFeeRecipient(), BRAIN);
        assertEq(strategy.pendingManagement(), BRAIN);

        // one vault per LP
        vm.expectRevert(YearnCurveLPVaultFactory.VaultAlreadyExist.selector);
        factory.deploy(LP, "x", "x");

        // Yearn adopts: Daddy adds the vault to the RoleManager, Brain accepts the strategy
        vm.prank(RM.getDaddy());
        RM.addNewVault(address(vault), 1);
        vm.prank(BRAIN);
        strategy.acceptManagement();
        assertEq(vault.role_manager(), address(RM));
        assertTrue(RM.isVaultsRoleManager(address(vault)));
        assertEq(vault.accountant(), RM.getAccountant());
        assertGt(vault.roles(BRAIN), 0);
        assertEq(strategy.management(), BRAIN);

        // deposit -> V2, Yearn keeper reports, redeem back
        address user = makeAddr("user");
        deal(LP, user, 100e18);
        vm.startPrank(user);
        IERC20(LP).approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        vm.stopPrank();
        assertEq(vault.totalIdle(), 0);
        assertGt(IERC20(V2).balanceOf(address(strategy)), 0);
        vm.prank(keeper);
        strategy.report();
        uint256 shares = vault.balanceOf(user);
        vm.prank(user);
        vault.redeem(shares, user, user);
        assertApproxEqAbs(IERC20(LP).balanceOf(user), 100e18, 1e6);
    }

    function test_ownerSettings() external {
        vm.createSelectFork("mainnet");
        YearnCurveLPVaultFactory factory = new DeployYearnLPVaultFactory().run();
        address stranger = makeAddr("stranger");
        bytes memory unauthorized = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);

        // only owner
        vm.startPrank(stranger);
        vm.expectRevert(unauthorized);
        factory.setV3Factory(IYearnVaultFactory(stranger));
        vm.expectRevert(unauthorized);
        factory.setRoleManager(IYearnRoleManager(stranger));
        vm.expectRevert(unauthorized);
        factory.renounceOwnership();
        vm.stopPrank();

        vm.startPrank(BRAIN);
        vm.expectRevert(YearnCurveLPVaultFactory.CannotRenounceOwnership.selector);
        factory.renounceOwnership();
        vm.expectRevert(YearnCurveLPVaultFactory.WrongFactory.selector);
        factory.setV3Factory(IYearnVaultFactory(address(0)));
        vm.expectRevert(YearnCurveLPVaultFactory.WrongRoleManager.selector);
        factory.setRoleManager(IYearnRoleManager(address(0)));

        // swap V3 factory (v3.0.4) and two-step ownership transfer
        address v304 = 0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F;
        factory.setV3Factory(IYearnVaultFactory(v304));
        factory.transferOwnership(stranger);
        vm.stopPrank();
        assertEq(factory.owner(), BRAIN);
        vm.prank(stranger);
        factory.acceptOwnership();
        assertEq(factory.owner(), stranger);

        (IYearnV3Vault vault,) = factory.deploy(LP, "Curve USG-USDC yVault", "yvCurve-USG-USDC");
        assertEq(vault.FACTORY(), v304);
    }
}

interface IVaultStrategies {
    function strategies(address) external view returns (uint256, uint256, uint256, uint256);
}
