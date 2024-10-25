import "forge-std/Script.sol"; // Import du module Foundry pour les scripts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BoosterListUI, BalancesAllowances} from "../../src/chainview/boosters/BoosterListUI.cv.sol";
import "../../src/libs/ResourcesGlobal.sol";
import "../../src/libs/ResourcesYieldSplitter.sol";
contract TriggerChainview is Script {
    address user1 = 0x22416Ff32559e4ea9E9168AbfFBAfcEdFCBB186E;
    address user2 = 0x4129CdB25B61448EB29249E0706B96cbaCd0d2c5;

    function run() public {
        vm.createSelectFork("mainnet", 21043100);
        BalancesAllowances.InputBalancesAllowances[] memory ibas = new BalancesAllowances.InputBalancesAllowances[](2);
        address[] memory spenders = new address[](1);
        spenders[0] = user2;

        ibas[0] = BalancesAllowances.InputBalancesAllowances({token: AddrClassicERC20.TOKEN_CRVUSD, spenders: spenders});
        ibas[1] = BalancesAllowances.InputBalancesAllowances({token: AddrClassicERC20.TOKEN_CRV, spenders: spenders});

        BoosterListUI boo = new BoosterListUI(user1, ibas);
    }
}
