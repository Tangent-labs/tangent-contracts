// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../src/libs/Resources/ResourcesCurveLP.sol";
import "../../../src/libs/Resources/ResourcesGlobal.sol";

import {FeeDispatcher} from "../../../src/USG/Utilities/FeeDispatcher.sol";
import {ZappingProxy} from "../../../src/USG/Utilities/ZappingProxy.sol";
import {OracleCurveEmaOrSpot} from "../../../src/USG/Oracles/Token/OracleCurveEmaOrSpot.sol";
import {OracleChainlinkWrapper} from "../../../src/USG/Oracles/Token/OracleChainlinkWrapper.sol";
import {IPriceOracle} from "../../../src/interfaces/internals/USG/IPriceOracle.sol";
import {IControlTower} from "../../../src/interfaces/internals/USG/IControlTower.sol";
import {ZapStruct} from "../../../src/interfaces/internals/ICommonStruct.sol";
import {IAggregatorStablePriceV3} from "../../../src/interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {ICurveStableSwapNG} from "../../../src/interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {MockRouter} from "../../mocks/MockRouter.sol";

/// @dev Gas of the dispatcher itself on prod USG + prod USG oracle + real reward oracles. Swap is mocked.
contract FeeDispatcherGas is Test {
    IERC20 constant USG = IERC20(0xB1c2Db5d6cA03FCe73dBd304d320bF76C55Ae1B1);
    IAggregatorStablePriceV3 constant USG_ORACLE = IAggregatorStablePriceV3(0x970b2F2cEc66F92dE81DAe6af363d1D135dD2F97);
    address constant BOLD_USDC_POOL = 0xEFc6516323FbD28e80B85A497B65A86243a54B3E;

    FeeDispatcher dispatcher;
    MockRouter router;
    IERC20 bold;
    IERC20[] tokens;

    function setUp() external {
        vm.createSelectFork("mainnet");
        address owner = makeAddr("owner");

        router = new MockRouter();
        dispatcher = new FeeDispatcher(owner, USG, new ZappingProxy(IControlTower(address(0))), USG_ORACLE, 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb);

        IPriceOracle eth = new OracleChainlinkWrapper(AddrChainlinkOracle.ETH, 3_900, address(new OracleChainlinkWrapper(AddrRestoneOracle.ETH, 90_000, address(0), "")), "");
        IPriceOracle usdc = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 90_000, address(new OracleChainlinkWrapper(AddrRestoneOracle.USDC, 90_000, address(0), "")), "");
        bold = IERC20(ICurveStableSwapNG(BOLD_USDC_POOL).coins(0));

        vm.startPrank(owner);
        _config(IERC20(address(AddrClassicERC20.CRV)), new OracleChainlinkWrapper(AddrChainlinkOracle.CRV, 90_000, address(0), ""), 100);
        _config(IERC20(address(AddrClassicERC20.FXN)), new OracleCurveEmaOrSpot(address(AddrCryptoSwapLP.FXN_ETH_POOL), eth, 0, false, ""), 200);
        _config(IERC20(address(AddrClassicERC20.PYUSD)), new OracleChainlinkWrapper(AddrChainlinkOracle.PYUSD, 90_000, address(0), ""), 30);
        _config(IERC20(address(AddrClassicERC20.RLUSD)), new OracleChainlinkWrapper(AddrChainlinkOracle.RLUSD, 90_000, address(0), ""), 30);
        _config(bold, new OracleCurveEmaOrSpot(BOLD_USDC_POOL, usdc, 0, true, ""), 50);
        vm.stopPrank();

        deal(address(USG), address(router), 10_000_000 ether);
    }

    function _config(IERC20 token, IPriceOracle oracle, uint16 slippage) internal {
        dispatcher.setTokenConfig(token, oracle, slippage);
        tokens.push(token);
    }

    function _params(IERC20 token) internal returns (FeeDispatcher.DumpParams memory) {
        uint256 amount = 10 ** IERC20Metadata(address(token)).decimals() * 100;
        deal(address(token), address(dispatcher), amount);
        uint256 out = dispatcher.oracleFloor(token, amount);
        return
            FeeDispatcher.DumpParams({
                tokenIn: token,
                amountIn: amount,
                minAmountOut: out,
                zap: ZapStruct({router: address(router), routerCall: abi.encodeCall(MockRouter.swap, (token, amount, USG, address(dispatcher.receiver()), out))})
            });
    }

    function _measure(FeeDispatcher.DumpParams[] memory dumps, string memory label) internal {
        // Cold access like a real tx: forget every slot / account touched while building the params
        vm.cool(address(dispatcher));
        vm.cool(address(USG_ORACLE));
        vm.cool(address(USG));
        vm.cool(address(router));
        vm.cool(address(dispatcher.zappingProxy()));
        vm.cool(address(dispatcher.receiver()));
        for (uint256 i; i < dumps.length; ++i) vm.cool(address(dumps[i].tokenIn));

        uint256 gasBefore = gasleft();
        dispatcher.dump(dumps);
        console.log(label, gasBefore - gasleft());
    }

    function _single(uint256 i, string memory label) internal {
        FeeDispatcher.DumpParams[] memory dumps = new FeeDispatcher.DumpParams[](1);
        dumps[0] = _params(tokens[i]);
        _measure(dumps, label);
    }

    function test_gas_usgPrice() external {
        vm.cool(address(USG_ORACLE));
        uint256 gasBefore = gasleft();
        dispatcher.usgPrice();
        console.log("usgPrice()", gasBefore - gasleft());
    }

    function test_gas_dump_CRV() external {
        _single(0, "dump CRV  ");
    }

    function test_gas_dump_FXN() external {
        _single(1, "dump FXN  ");
    }

    function test_gas_dump_PYUSD() external {
        _single(2, "dump PYUSD");
    }

    function test_gas_dump_RLUSD() external {
        _single(3, "dump RLUSD");
    }

    function test_gas_dump_BOLD() external {
        _single(4, "dump BOLD ");
    }

    function test_gas_dump_all_5() external {
        FeeDispatcher.DumpParams[] memory dumps = new FeeDispatcher.DumpParams[](5);
        for (uint256 i; i < 5; ++i) dumps[i] = _params(tokens[i]);
        _measure(dumps, "dump 5 tokens");
    }
}

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
