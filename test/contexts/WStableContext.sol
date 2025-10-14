// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OraclesContext.sol";

contract WStableContext is OraclesContext {
    WStable public wcrvUSD;
    WStable public wUSDE;
    WStable public wDOLA;
    WStable public wUSR;
    constructor() {
        vm.startPrank(owner);
        // wcrvUSD
        wcrvUSD = new WStable("wcrvUSD", "wcrvUSD", controlTower, AddrClassicERC20.crvUSD, AddrERC4626.scrvUSD, owner);
        deal(address(AddrClassicERC20.crvUSD), owner, 100_000 ether);
        AddrClassicERC20.crvUSD.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(100_000 ether, owner, false);

        // wUSDE
        wUSDE = new WStable("wUSDE", "wUSDE", controlTower, AddrClassicERC20.USDe, AddrERC4626.sUSDe, owner);
        deal(address(AddrClassicERC20.USDe), owner, 100_000 ether);
        AddrClassicERC20.USDe.approve(address(wUSDE), MAX_UINT);
        wUSDE.mint(100_000 ether, owner, false);
        // wDOLA
        wDOLA = new WStable("wDOLA", "wDOLA", controlTower, AddrClassicERC20.DOLA, AddrERC4626.sDOLA, owner);
        deal(address(AddrClassicERC20.DOLA), owner, 100_000 ether);
        AddrClassicERC20.DOLA.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(100_000 ether, owner, false);

        // wUSR
        wUSR = new WStable("wUSR", "wUSR", controlTower, AddrClassicERC20.USR, AddrERC4626.wstUSR, owner);
        deal(address(AddrClassicERC20.USR), owner, 100_000 ether);
        AddrClassicERC20.USR.approve(address(wUSR), MAX_UINT);
        wUSR.mint(100_000 ether, owner, false);
        vm.stopPrank();

        vm.label(address(wcrvUSD), "wcrvUSD");
        vm.label(address(wUSDE), "wUSDE");
        vm.label(address(wDOLA), "wDOLA");
        vm.label(address(wUSR), "wUSR");

        LpDeploymentContext.CreateUSGLpStruct[] memory params = new LpDeploymentContext.CreateUSGLpStruct[](4);
        params[0] = LpDeploymentContext.CreateUSGLpStruct({otherStable: wcrvUSD, name: "USG-wcrvUSD", symbol: "wcrvUSD", initialAmount: 500_000});
        params[1] = LpDeploymentContext.CreateUSGLpStruct({otherStable: wUSDE, name: "USG-wUSDe", symbol: "wUSDe", initialAmount: 500_000});
        params[2] = LpDeploymentContext.CreateUSGLpStruct({otherStable: wDOLA, name: "USG-wDOLA", symbol: "wDOLA", initialAmount: 500_000});
        params[3] = LpDeploymentContext.CreateUSGLpStruct({otherStable: wUSR, name: "USG-wUSR", symbol: "wUSR", initialAmount: 500_000});
        lpDeploymentContext.createUSGLps(owner, params);

        setupUSGOracle();
    }
}
