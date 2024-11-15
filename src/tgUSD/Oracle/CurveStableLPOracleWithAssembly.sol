// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// import "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
// import "../../interfaces/externals/Chainlink/IAggregatorV3.sol";

// import "forge-std/console.sol";

// contract CurveStableLPOracleWithAssembly {
//     bytes4 constant selectorGetVirtualPrice = bytes4(keccak256("get_virtual_price()"));

//     mapping(address => uint256) curveLPType;

//     IERC20Metadata coin0;
//     IERC20Metadata coin1;

//     IAggregatorV3 coin0Oracle;
//     IAggregatorV3 coin1Oracle;

//     uint256 coin0Decimals;
//     uint256 coin1Decimals;

//     uint256 coin0OracleDecimals;
//     uint256 coin1OracleDecimals;

//     ICurveStableSwapNG lp;

//     constructor(ICurveStableSwapNG _lp, IAggregatorV3 _coin0Oracle, IAggregatorV3 _coin1Oracle) {
//         lp = _lp;

//         IERC20Metadata _coin0 = IERC20Metadata(_lp.coins(0));
//         coin0 = _coin0;
//         coin0Decimals = _coin0.decimals();

//         IERC20Metadata _coin1 = IERC20Metadata(_lp.coins(1));
//         coin1 = _coin1;
//         coin1Decimals = _coin1.decimals();

//         coin0Oracle = _coin0Oracle;
//         coin1Oracle = _coin1Oracle;

//         coin0OracleDecimals = _coin0Oracle.decimals();
//         coin1OracleDecimals = _coin1Oracle.decimals();
//     }

//     function min(uint256 a, uint256 b) internal pure returns (uint256) {
//         if (a > b) {
//             return b;
//         }

//         return a;
//     }

//     function getLPPrice() external view returns (uint256) {
//         address _aggreg0;
//         address _aggreg1;

//         uint256 _coin0OracleDecimals;
//         uint256 _coin1OracleDecimals;

//         uint256 virtualPrice;
//         assembly {
//             _aggreg0 := and(sload(3), 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)

//             _aggreg1 := and(sload(4), 0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)

//             _coin0OracleDecimals := sload(5)

//             _coin1OracleDecimals := sload(6)

//             _coin1OracleDecimals := sload(6)

//             // _coin1OracleDecimals := sload(9)

//             // Position et taille de `selector`
//             let selectorPtr := mload(0x40) // Pointeur mémoire libre
//             mstore(selectorPtr, selectorGetVirtualPrice) // Stocker le sélecteur à cette position

//             // Allocation de mémoire pour la réponse (32 octets suffisent pour un uint256)
//             let resultPtr := add(selectorPtr, 0x20) // Pointeur pour le retour de l’appel

//             // Appel de la fonction `getValue` dans le contrat `otherContract`
//             let success := staticcall(
//                 gas(), // Gaz disponible pour l'appel
//                 sload(9), // Adresse du contrat cible
//                 selectorPtr, // Position du sélecteur en mémoire
//                 0x04, // Taille du sélecteur (4 octets pour le `bytes4`)
//                 resultPtr, // Position de mémoire pour stocker le retour
//                 0x20 // Taille de l'espace de retour (32 octets pour un uint256)
//             )

//             // Vérification de la réussite de l'appel
//             if iszero(success) {
//                 revert(0, 0)
//             }
//             // Charger le résultat depuis `resultPtr`
//             virtualPrice := mload(resultPtr)
//         }

//         (, int256 a0, , uint256 lastUpdate0, ) = IAggregatorV3(_aggreg0).latestRoundData();
//         (, int256 a1, , uint256 lastUpdate1, ) = IAggregatorV3(_aggreg1).latestRoundData();

//         uint256 answer0 = uint256(a0) * 10 ** (18 - _coin0OracleDecimals);
//         uint256 answer1 = uint256(a1) * 10 ** (18 - _coin1OracleDecimals);

//         return (virtualPrice * min(uint256(answer0), uint256(answer1))) / 10 ** 18;
//     }
// }
