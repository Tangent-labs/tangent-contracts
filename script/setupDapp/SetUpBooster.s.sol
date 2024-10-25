import {MainSetup} from "./MainSetup.s.sol";

import "forge-std/Test.sol";

import "../../src/libs/ResourcesGlobal.sol";
import "../../src/libs/ResourcesBooster.sol";
contract SetUpBooster is MainSetup, Test {
    event Aa();
    function run() public {
        vm.chainId(31337);
        vm.rpcUrl("http://127.0.0.1:8545");

        IERC20[12] memory erc20s = [
            AddrClassicERC20.TOKEN_CRV,
            AddrClassicERC20.TOKEN_BAL,
            AddrClassicERC20.TOKEN_PENDLE,
            AddrClassicERC20.TOKEN_FXN,
            AddrBooster.SD_CRV,
            AddrBooster.SD_BAL,
            AddrBooster.SD_PENDLE,
            AddrBooster.SD_FXN,
            AddrBooster.SD_CRV_GAUGE,
            AddrBooster.SD_BAL_GAUGE,
            AddrBooster.SD_PENDLE_GAUGE,
            AddrBooster.SD_FXN_GAUGE
        ];

        for (uint256 userIndex; userIndex < pkUsers.length; userIndex++) {
            address user = pkUsers[userIndex].user;
            deal(user, 100 ether);

            uint256 pk = pkUsers[userIndex].pk;
            console.log("Ma balance 1", user.balance);

            vm.startBroadcast(pk);

            // // Gives ERC20 to all users
            // for (uint256 erc20Index; erc20Index < erc20s.length; erc20Index++) {
            //     deal(address(erc20s[erc20Index]), user, 1_000_000 ether);
            // }

            console.log("Ma balance 2", user.balance);
            AddrBooster.SD_CRV_GAUGE.approve(address(AddrBooster.SD_BAL_STAKING), 1_000_000 ether);
            vm.stopBroadcast();
        }
        emit Aa();
    }
}
