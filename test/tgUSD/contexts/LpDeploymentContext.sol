// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../src/libs/Resources/ResourcesGlobal.sol";
import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../utils/Array.sol";
contract LpDeploymentContext is StdCheats, StdUtils, Test {
    using SafeERC20 for IERC20Metadata;
    uint256 public constant MAX_UINT = uint256(int256(-1));

    mapping(string => ICurveStableSwapNG) public tgUSDLPs;

    IERC20 public tgUSD;

    struct CreateTgUSDLpStruct {
        IERC20Metadata otherStable;
        string name;
        string symbol;
        uint256 initialAmount;
    }

    constructor(address creator, IERC20 _tgUSD) {
        tgUSD = _tgUSD;
        CreateTgUSDLpStruct[] memory params = new CreateTgUSDLpStruct[](1);
        params[0] = CreateTgUSDLpStruct({otherStable: AddrClassicERC20.USDC, name: "tgUSD-USDC", symbol: "tgUSDC", initialAmount: 500_000});
        createTgUSDLps(creator, params);
    }

    function createTgUSDLps(address creator, CreateTgUSDLpStruct[] memory createTgUSDParams) public {
        for (uint256 i; i < createTgUSDParams.length; i++) {
            _deployTgUSDLP(creator, createTgUSDParams[i].otherStable, createTgUSDParams[i].name, createTgUSDParams[i].symbol, createTgUSDParams[i].initialAmount);
        }
    }

    function _deployTgUSDLP(address creator, IERC20Metadata otherStable, string memory name, string memory symbol, uint256 initialAmount) internal {
        uint256 otherStableDecimals = otherStable.decimals();
        // Give otherStable to owner before LP deployment
        deal(address(otherStable), creator, initialAmount * 10 ** otherStableDecimals);
        vm.startPrank(creator);

        ICurveStableSwapNG lpTgUSD = ICurveStableSwapNG(
            AddrCurveStableLP.STABLE_SWAP_FACTORY.deploy_plain_pool(
                name,
                symbol,
                Array.memoryAddress([address(otherStable), address(tgUSD)]),
                500,
                1000000,
                0,
                866,
                0,
                Array.memoryUint8([uint8(0), uint8(0)]),
                Array.memoryBytes4([bytes4(0), bytes4(0)]),
                Array.memoryAddress([address(0), address(0)])
            )
        );
        otherStable.forceApprove(address(lpTgUSD), MAX_UINT);
        tgUSD.approve(address(lpTgUSD), MAX_UINT);

        lpTgUSD.add_liquidity(Array.memoryUint256([uint256(initialAmount * 10 ** otherStableDecimals), uint256(initialAmount * 10 ** 18)]), uint256(0));
        vm.label(address(lpTgUSD), name);
        tgUSDLPs[name] = lpTgUSD;

        vm.stopPrank();
    }
}
