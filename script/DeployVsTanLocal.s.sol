// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {VsTAN} from "src/USG/Tokens/VsTAN.sol";
import {USG as USGToken} from "src/USG/Tokens/USG.sol";
import {TokenAmount} from "src/interfaces/internals/USG/IRewardAccumulator.sol";
import {IControlTower} from "src/interfaces/internals/USG/IControlTower.sol";
import {IZappingProxy} from "src/interfaces/internals/USG/IZappingProxy.sol";
import {ICurveCryptoSwap} from "src/interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {AddrCryptoSwapLP} from "src/libs/Resources/ResourcesCurveLP.sol";
import {AddrClassicERC20} from "src/libs/Resources/ResourcesGlobal.sol";

/// Local mainnet fork only (anvil --fork-url $FORK_RPC). Optimizer is needed to fit EIP-170.
/// FOUNDRY_OPTIMIZER=true FOUNDRY_OPTIMIZER_RUNS=200 forge script script/DeployVsTanLocal.s.sol --rpc-url forkito --broadcast --unlocked --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
contract DeployVsTanLocal is Script {
    address constant DAO = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;
    IERC20 constant TAN = IERC20(0xe6a705945Bf67a43BBb237B9EbD2C77801483eAc);
    IControlTower constant CONTROL_TOWER = IControlTower(0xF3f7669dcEED2f985815011C19eD68F667267215);
    USGToken constant USG = USGToken(0xB1c2Db5d6cA03FCe73dBd304d320bF76C55Ae1B1);
    address constant USG_OWNER = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;
    IERC4626 constant SUSG = IERC4626(0xF17D6f98A5C6EAA99d149079984119e0A4EF6900);
    IZappingProxy constant ZAPPING_PROXY = IZappingProxy(0xA9E0021d8917C51F496823605d218d7E78719c99);
    IERC20 constant WETH = IERC20(address(AddrClassicERC20.WETH));

    string constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
    uint256 constant N_USERS = 5;
    uint256 constant TAN_PER_USER = 100_000 ether;
    uint256 constant TAN_LOCKED_PER_USER = 50_000 ether;
    uint256 constant USG_REWARDS = 1_000 ether; // streamed over 1 week
    // Seed liquidity, same ratio as LpDeploymentContext
    uint256 constant LP_WETH = 200 ether;
    uint256 constant LP_TAN = 3_330_000 ether;

    function run() external returns (VsTAN vsTan, ICurveCryptoSwap tanEthLp) {
        address deployer = vm.addr(vm.deriveKey(ANVIL_MNEMONIC, 0));
        vm.startBroadcast(deployer);
        vsTan = new VsTAN(DAO, CONTROL_TOWER, TAN, IERC20(address(USG)), SUSG, ZAPPING_PROXY, 100 ether);
        vm.stopBroadcast();

        // Impersonate the DAO and USG owner on the anvil node itself, and give them ETH (300 ETH for gas + LP seeding)
        _impersonate(DAO);
        _impersonate(USG_OWNER);

        // Let the DAO mint USG for the rewards
        vm.startBroadcast(USG_OWNER);
        USG.setIsMinter(DAO, true);
        vm.stopBroadcast();

        vm.startBroadcast(DAO);
        for (uint256 i = 1; i <= N_USERS; i++) {
            address user = vm.addr(vm.deriveKey(ANVIL_MNEMONIC, uint32(i)));
            TAN.transfer(user, TAN_PER_USER);
            console.log("Sent TAN to", user);
        }
        vsTan.addNewReward(IERC20(address(USG)));
        vm.stopBroadcast();

        // Users lock part of their TAN so the streamed rewards have someone to go to
        for (uint256 i = 1; i <= N_USERS; i++) {
            vm.startBroadcast(vm.addr(vm.deriveKey(ANVIL_MNEMONIC, uint32(i))));
            TAN.approve(address(vsTan), TAN_LOCKED_PER_USER);
            vsTan.createLock(uint208(TAN_LOCKED_PER_USER), false);
            vm.stopBroadcast();
        }

        vm.startBroadcast(DAO);
        USG.mintDebt(DAO, USG_REWARDS);
        USG.approve(address(vsTan), USG_REWARDS);
        TokenAmount[] memory rewards = new TokenAmount[](1);
        rewards[0] = TokenAmount({token: IERC20(address(USG)), amount: USG_REWARDS});
        vsTan.processRewards(rewards);

        // twocrypto-ng WETH/TAN, params from LpDeploymentContext; initial_price = TAN price in WETH
        tanEthLp = ICurveCryptoSwap(
            AddrCryptoSwapLP.CRYPTO_SWAP_FACTORY.deploy_pool(
                "TANETH",
                "TANETH",
                [address(WETH), address(TAN)],
                0,
                400000,
                145000000000000,
                26000000,
                45000000,
                230000000000000,
                2000000000000,
                146000000000000,
                866,
                (LP_WETH * 1e18) / LP_TAN
            )
        );
        (bool ok, ) = address(WETH).call{value: LP_WETH}("");
        require(ok, "WETH wrap");
        WETH.approve(address(tanEthLp), LP_WETH);
        TAN.approve(address(tanEthLp), LP_TAN);
        tanEthLp.add_liquidity([LP_WETH, LP_TAN], 0);
        vm.stopBroadcast();

        console.log("VsTAN deployed at", address(vsTan));
        console.log("TAN/ETH LP deployed at", address(tanEthLp));
    }

    function _impersonate(address account) internal {
        vm.rpc("anvil_impersonateAccount", string.concat('["', vm.toString(account), '"]'));
        vm.rpc("anvil_setBalance", string.concat('["', vm.toString(account), '","0x1043561a8829300000"]'));
    }
}
