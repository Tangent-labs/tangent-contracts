// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OraclesContext.sol";

contract TgStableContext is OraclesContext {
    uint256 socFeePercentage = 2_000;
    TgStable public tgCrvUSD;
    TgStable public tgDAI;
    TgStable public tgFRAX;
    TgStable public tgDOLA;
    constructor() {
        vm.startPrank(owner);

        // tgCRVUSD
        tgCrvUSD = new TgStable("tgCRVUSD", "tgCRVUSD", controlTower, AddrClassicERC20.TOKEN_CRVUSD, AddrERC4626.S_CRVUSD, owner, socFeePercentage);
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_CRVUSD.approve(address(tgCrvUSD), MAX_UINT);
        tgCrvUSD.mint(owner, 100_000 ether, true);

        // tgDAI
        tgDAI = new TgStable("tgDAI", "tgDAI", controlTower, AddrClassicERC20.TOKEN_DAI, AddrERC4626.S_DAI, owner, socFeePercentage);
        deal(address(AddrClassicERC20.TOKEN_DAI), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_DAI.approve(address(tgDAI), MAX_UINT);
        tgDAI.mint(owner, 100_000 ether, true);

        // tgFRAX
        tgFRAX = new TgStable("tgFRAX", "tgFRAX", controlTower, AddrClassicERC20.TOKEN_FRAX, AddrERC4626.S_FRAX, owner, socFeePercentage);
        deal(address(AddrClassicERC20.TOKEN_FRAX), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_FRAX.approve(address(tgFRAX), MAX_UINT);
        tgFRAX.mint(owner, 100_000 ether, true);

        // tgDOLA
        tgDOLA = new TgStable("tgDOLA", "tgDOLA", controlTower, AddrClassicERC20.TOKEN_DOLA, AddrERC4626.S_DOLA, owner, socFeePercentage);
        deal(address(AddrClassicERC20.TOKEN_DOLA), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_DOLA.approve(address(tgDOLA), MAX_UINT);
        tgDOLA.mint(owner, 100_000 ether, true);

        vm.stopPrank();

        LpDeploymentContext.CreateTgUSDLpStruct[] memory params = new LpDeploymentContext.CreateTgUSDLpStruct[](3);
        params[0] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: tgCrvUSD, name: "tgUSD-wCrvUSD", symbol: "tgCrvUSD", initialAmount: 5_000});
        params[1] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: tgDOLA, name: "tgUSD-wDOLA", symbol: "tgDOLA", initialAmount: 5_000});
        params[2] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: tgDAI, name: "tgUSD-wDAI", symbol: "tgDAI", initialAmount: 5_000});
        lpDeploymentContext.createTgUSDLps(owner, params);
    }
}
