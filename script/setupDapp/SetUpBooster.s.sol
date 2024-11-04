import {MainSetup} from "./MainSetup.s.sol";

import "forge-std/Test.sol";

import "../../src/libs/resources/ResourcesGlobal.sol";
import "../../src/libs/resources/ResourcesBooster.sol";
contract SetUpBooster is MainSetup, Test {
    function setUp() public {
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

        console.log("balance my ass", AddrClassicERC20.TOKEN_CRV.balanceOf(user0));
        console.log("allow my ass", AddrBooster.SD_CRV_GAUGE.allowance(user0, address(AddrBooster.SD_BAL_STAKING)));

        for (uint256 userIndex; userIndex < pkUsers.length; userIndex++) {
            address user = pkUsers[userIndex].user;
            deal(user, 100 ether);

            uint256 pk = pkUsers[userIndex].pk;
            console.log("Ma balance 1", user.balance);

            // Gives ERC20 to all users
            for (uint256 erc20Index; erc20Index < erc20s.length; erc20Index++) {
                uint256 amount = 1000 ether;
                uint256 balancesOfSlot = 12;
                bytes32 storagePosition = keccak256(abi.encodePacked(user, balancesOfSlot));
                vm.makePersistent(address(erc20s[erc20Index]));
                vm.store(address(erc20s[erc20Index]), storagePosition, bytes32(amount));
            }

            console.log("Ma balance 2", user.balance);
            AddrBooster.SD_CRV_GAUGE.approve(address(AddrBooster.SD_BAL_STAKING), 1_000_000 ether);
        }
    }

    function test_oo() public {}
}
