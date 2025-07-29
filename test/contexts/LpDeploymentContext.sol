// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../src/libs/Resources/ResourcesGlobal.sol";
import "../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../src/interfaces/externals/Curve/ICurveCryptoSwap.sol";
import "../utils/Array.sol";

contract LpDeploymentContext is StdCheats, StdUtils, Test {
    using SafeERC20 for IERC20Metadata;
    uint256 public constant MAX_UINT = uint256(int256(-1));

    mapping(string => ICurveStableSwapNG) public USGLPs;

    ICurveCryptoSwap public tanETHLp;

    IERC20 public USG;

    IERC20 public tan;

    struct CreateUSGLpStruct {
        IERC20Metadata otherStable;
        string name;
        string symbol;
        uint256 initialAmount;
    }

    constructor(address creator, IERC20 _USG, IERC20 _tan) {
        USG = _USG;
        tan = _tan;
        CreateUSGLpStruct[] memory params = new CreateUSGLpStruct[](1);
        params[0] = CreateUSGLpStruct({otherStable: AddrClassicERC20.USDC, name: "USG-USDC", symbol: "USGC", initialAmount: 500_000});
        createUSGLps(creator, params);
        _deployTanETHLP(creator);
    }

    function createUSGLps(address creator, CreateUSGLpStruct[] memory createUSGParams) public {
        for (uint256 i; i < createUSGParams.length; i++) {
            _deployUSGLP(creator, createUSGParams[i].otherStable, createUSGParams[i].name, createUSGParams[i].symbol, createUSGParams[i].initialAmount);
        }
    }

    function _deployUSGLP(address creator, IERC20Metadata otherStable, string memory name, string memory symbol, uint256 initialAmount) internal {
        uint256 otherStableDecimals = otherStable.decimals();
        // Give otherStable to owner before LP deployment
        deal(address(otherStable), creator, initialAmount * 10 ** otherStableDecimals);
        vm.startPrank(creator);

        ICurveStableSwapNG lpUSG = ICurveStableSwapNG(
            AddrCurveStableLP.STABLE_SWAP_FACTORY.deploy_plain_pool(
                name,
                symbol,
                Array.memoryAddress([address(otherStable), address(USG)]),
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
        otherStable.forceApprove(address(lpUSG), MAX_UINT);
        USG.approve(address(lpUSG), MAX_UINT);

        lpUSG.add_liquidity(Array.memoryUint256([uint256(initialAmount * 10 ** otherStableDecimals), uint256(initialAmount * 10 ** 18)]), uint256(0));
        vm.label(address(lpUSG), name);
        USGLPs[name] = lpUSG;

        vm.stopPrank();
    }

    function _deployTanETHLP(address creator) internal {
        IERC20 otherToken = AddrClassicERC20.WETH;
        // Give otherStable to owner before LP deployment
        deal(address(otherToken), creator, 200 * 1 ether);
        vm.startPrank(creator);

        ICurveCryptoSwap _tanETHLp = ICurveCryptoSwap(
            AddrCryptoSwapLP.CRYPTO_SWAP_FACTORY.deploy_pool(
                "TANA",
                "TANA",
                [address(otherToken), address(tan)],
                0,
                400000,
                145000000000000,
                26000000,
                45000000,
                230000000000000,
                2000000000000,
                146000000000000,
                866,
                6006006006000
            )
        );

        otherToken.approve(address(_tanETHLp), MAX_UINT);
        tan.approve(address(_tanETHLp), MAX_UINT);
        _tanETHLp.add_liquidity([uint256(200 * 10 ** 18), uint256(3_330_000 * 10 ** 18)], uint256(0));

        vm.label(address(_tanETHLp), "TAN-ETH LP");
        tanETHLp = _tanETHLp;

        vm.stopPrank();
    }
}
