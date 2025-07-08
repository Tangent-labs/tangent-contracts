// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract ZappingProxyBranches is MarketDeploymentContext {
    ICurveRouter ROUTER = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    uint256 amount = 10 * 10 ** 18;

    function test_zapProxy_fails_with_tokenIn_equals_tokenOut() external {
        vm.expectRevert(abi.encodeWithSelector(ZappingProxy.TokenInOutMustBeDifferent.selector));
        zappingProxy.zapProxy(AddrClassicERC20.CRV, AddrClassicERC20.CRV, 0, usr1, ZapStruct(address(0), ""));
    }

    function test_zapProxy_fails_with_msgValue_zero_and_ETH_as_tokenIn() external {
        vm.expectRevert(abi.encodeWithSelector(ZappingProxy.TokenInMustNotBeETH.selector));
        zappingProxy.zapProxy{value: 0}(ETH_NAKED, AddrClassicERC20.CRV, 0, usr1, ZapStruct(address(0), ""));
    }

    function test_zapProxy_fails_with_msgValue_bigger_zero_and_tokenIn_not_ETH() external {
        vm.expectRevert(abi.encodeWithSelector(ZappingProxy.TokenInMustBeETH.selector));
        zappingProxy.zapProxy{value: 10 ether}(AddrClassicERC20.CRV, AddrClassicERC20.USDC, 0, usr1, ZapStruct(address(0), ""));
    }
}
