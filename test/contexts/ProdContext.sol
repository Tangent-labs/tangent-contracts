 // // SPDX-License-Identifier: UNLICENSED

// pragma solidity ^0.8.22;

// import {StdCheats} from "forge-std/StdCheats.sol";
// import {StdUtils} from "forge-std/StdUtils.sol";

// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

// import "../../src/libs/Resources/ResourcesConvex.sol";
// import "../../src/libs/Resources/ResourcesCurveLP.sol";
// import "../../src/libs/Resources/ResourcesPendle.sol";
// import "../../src/libs/Resources/ResourcesYearn.sol";
// import "../../src/libs/Resources/ResourcesStakeDao.sol";

// import "../../src/USG/Tokens/VsTAN.sol";
// import "../../src/USG/Tokens/TAN.sol";
// import "../../src/USG/Tokens/USG.sol";
// import "../../src/USG/Tokens/WStable.sol";
// import "../../src/USG/Utilities/RewardAccumulator.sol";
// import "../../src/USG/Utilities/ControlTower.sol";
// import "../../src/USG/Utilities/MarketCreator.sol";
// import "../../src/USG/Utilities/MarketViewer.sol";
// import "../../src/USG/Utilities/ZappingProxy.sol";
// import "../../src/USG/Utilities/Migratoor.sol";
// import "../../src/USG/Utilities/abstract/LightReentrancyGuardTransient.sol";
// import "../../src/USG/Routers/PendlePTRouter.sol";

// import "../mocks/MockRouter.sol";

// import "../../src/USG/Market/Convex/ConvexCrvLPMarket.sol";
// import "../../src/USG/Market/Convex/ConvexFxnLPMarket.sol";
// import "../../src/USG/Market/BasicERC20Market.sol";
// import "../../src/USG/Market/Curve/CurveGaugeMarket.sol";
// import "../../src/USG/Market/StakeDao/StakeDaoVaultV2Market.sol";

// import "../../src/USG/Market/BasicERC20Market.sol";
// import "../../src/USG/Market/abstract/MarketCore.sol";
// import "../../src/USG/Market/abstract/DebtIR.sol";

// import "../utils/AssertERC20.sol";
// import "../utils/LowLevel.sol";
// import "../utils/EnsoUtils.sol";
// import "../utils/Labeliser.sol";
// import "../utils/Array.sol";
// import "../utils/String.sol";
// import "../utils/Encoder.sol";
// import "../../src/interfaces/externals/YearnFi/IYearnV3Vault.sol";
// import "../../src/interfaces/externals/ICREATE3Factory.sol";

// contract ProdContext is StdCheats, StdUtils, Test {
//     mapping(string => IStakeDaoVaultV2Market) public stakeDaoMarkets;

//     constructor(address creator, IERC20 _USG, IERC20 _tan) {
//         stakeDaoMarkets["USDT_crvUSD"] = IStakeDaoVaultV2Market();
//     }
// }
