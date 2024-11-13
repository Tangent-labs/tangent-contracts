import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../../../src/libs/resources/ResourcesGlobal.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/tgUSD/Oracle/CurveStableLPOracle.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract TgUSDDeployContext is StdCheats, StdUtils, Test {
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    address processor = makeAddr("Processor");

    uint256 public MAX_UINT = uint256(int256(-1));

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = makeAddr("feeTreasury");

    CurveStableLPOracle public curveLPOracle;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function deployBaseContracts() public {
        vm.createSelectFork("mainnet", 21093905);
        curveLPOracle = new CurveStableLPOracle(AddrCurveStableLP.CRVUSD_USDC, AddrChainlinkOracle.USDC, AddrChainlinkOracle.CRVUSD);
    }
}
