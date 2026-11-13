// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployYearnLPVaultFactory} from "script/DeployYearnLPVaultFactory.s.sol";
import {YearnCurveLPVaultFactory} from "src/USG/Utilities/YearnCurveLPVaultFactory.sol";
import {IYearnVaultFactory} from "src/interfaces/externals/YearnFi/IYearnVaultFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRouterV2} from "src/interfaces/externals/YearnFi/IRouterV2.sol";
import {IYearnV3Vault} from "src/interfaces/externals/YearnFi/IYearnV3Vault.sol";

contract YearnLPVaultFactoryTest is Test {
    address constant LP = 0x97BA10115da528c113462EDE9C20D7adc806D93f; // USG-USDC
    address constant V2 = 0x2FEE733d8939343615a8627BC29f95390a161e74;
    address constant MULTISIG = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;

    function test_factory() external {
        vm.createSelectFork("mainnet");
        YearnCurveLPVaultFactory factory = new DeployYearnLPVaultFactory().run();

        // permissionless deploy
        vm.prank(makeAddr("anyone"));
        (IYearnV3Vault vault, IRouterV2 strategy) = factory.deploy(LP, "Curve USG-USDC yVault", "yvCurve-USG-USDC");
        assertEq(factory.vaults(LP), address(vault));

        // vault config
        assertEq(vault.asset(), LP);
        assertEq(vault.name(), "Curve USG-USDC yVault");
        assertEq(vault.deposit_limit(), 1e29);
        assertEq(vault.profitMaxUnlockTime(), 4 days);
        assertEq(vault.accountant(), address(0));
        assertTrue(vault.auto_allocate());
        address[] memory queue = vault.get_default_queue();
        assertEq(queue.length, 1);
        assertEq(queue[0], address(strategy));
        (,,, uint256 maxDebt) = IVaultStrategies(address(vault)).strategies(address(strategy));
        assertEq(maxDebt, 1e29);

        // vault roles: factory keeps nothing, multisig has everything and is pending role manager
        assertEq(vault.roles(address(factory)), 0);
        assertEq(vault.roles(MULTISIG), 0x3fff);
        assertEq(vault.future_role_manager(), MULTISIG);

        // strategy config
        assertEq(strategy.asset(), LP);
        assertEq(strategy.V2_VAULT(), V2);
        assertTrue(strategy.allowed(address(vault)));
        assertEq(strategy.performanceFee(), 0);
        assertEq(strategy.profitMaxUnlockTime(), 0);
        assertEq(strategy.keeper(), MULTISIG);
        assertEq(strategy.emergencyAdmin(), MULTISIG);
        assertEq(strategy.performanceFeeRecipient(), MULTISIG);
        assertEq(strategy.pendingManagement(), MULTISIG);
        // same TokenizedStrategy impl / version as Yearn's own RouterV2 strategy
        IYearnStrategyInfo yearn = IYearnStrategyInfo(0xB6d651A1b8f63852DA92d126823d398db1c71002);
        assertEq(IYearnStrategyInfo(address(strategy)).apiVersion(), yearn.apiVersion());
        assertEq(IYearnStrategyInfo(address(strategy)).tokenizedStrategyAddress(), yearn.tokenizedStrategyAddress());

        // one vault per LP
        vm.expectRevert(YearnCurveLPVaultFactory.VaultAlreadyExist.selector);
        factory.deploy(LP, "x", "x");

        // multisig accepts
        vm.startPrank(MULTISIG);
        vault.accept_role_manager();
        strategy.acceptManagement();
        vm.stopPrank();
        assertEq(vault.role_manager(), MULTISIG);
        assertEq(strategy.management(), MULTISIG);

        // deposit -> V2, redeem back
        address user = makeAddr("user");
        deal(LP, user, 100e18);
        vm.startPrank(user);
        IERC20(LP).approve(address(vault), 100e18);
        vault.deposit(100e18, user);
        assertEq(vault.totalIdle(), 0);
        assertGt(IERC20(V2).balanceOf(address(strategy)), 0);
        vault.redeem(vault.balanceOf(user), user, user);
        vm.stopPrank();
        assertApproxEqAbs(IERC20(LP).balanceOf(user), 100e18, 1e6);
    }

    function test_ownerAndV3Factory() external {
        vm.createSelectFork("mainnet");
        YearnCurveLPVaultFactory factory = new DeployYearnLPVaultFactory().run();
        address newAdmin = makeAddr("newAdmin");
        address stranger = makeAddr("stranger");
        address newV3Factory = 0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F; // Yearn v3.0.4 factory

        bytes memory unauthorized = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);
        assertEq(factory.owner(), MULTISIG);

        // only owner
        vm.startPrank(stranger);
        vm.expectRevert(unauthorized);
        factory.transferOwnership(stranger);
        vm.expectRevert(unauthorized);
        factory.setV3Factory(IYearnVaultFactory(stranger));
        vm.stopPrank();

        // two-step ownership transfer
        vm.prank(MULTISIG);
        factory.transferOwnership(newAdmin);
        assertEq(factory.owner(), MULTISIG);
        vm.prank(stranger);
        vm.expectRevert(unauthorized);
        factory.acceptOwnership();
        vm.prank(newAdmin);
        factory.acceptOwnership();
        assertEq(factory.owner(), newAdmin);
        assertEq(factory.pendingOwner(), address(0));

        // ownership cannot be renounced
        vm.prank(stranger);
        vm.expectRevert(unauthorized);
        factory.renounceOwnership();
        vm.prank(newAdmin);
        vm.expectRevert(YearnCurveLPVaultFactory.CannotRenounceOwnership.selector);
        factory.renounceOwnership();
        assertEq(factory.owner(), newAdmin);

        // new owner swaps the V3 factory
        vm.startPrank(newAdmin);
        vm.expectRevert(YearnCurveLPVaultFactory.WrongFactory.selector);
        factory.setV3Factory(IYearnVaultFactory(address(0)));
        factory.setV3Factory(IYearnVaultFactory(newV3Factory));
        vm.stopPrank();
        assertEq(address(factory.v3Factory()), newV3Factory);

        // next deploy uses the new V3 factory and hands roles to the new owner
        (IYearnV3Vault vault, IRouterV2 strategy) = factory.deploy(LP, "Curve USG-USDC yVault", "yvCurve-USG-USDC");
        assertEq(vault.FACTORY(), newV3Factory);
        assertEq(vault.roles(newAdmin), 0x3fff);
        assertEq(vault.future_role_manager(), newAdmin);
        assertEq(strategy.pendingManagement(), newAdmin);
        assertEq(strategy.keeper(), newAdmin);
    }
}

interface IVaultStrategies {
    function strategies(address) external view returns (uint256, uint256, uint256, uint256);
}

interface IYearnStrategyInfo {
    function apiVersion() external view returns (string memory);
    function tokenizedStrategyAddress() external view returns (address);
}
