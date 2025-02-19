// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OraclesContext.sol";

contract TgStableContext is OraclesContext {
    uint256 socFeePercentage = 2_000;
    WStable public wfrxUSD;
    WStable public wcrvUSD;
    WStable public wUSDE;
    WStable public wDOLA;
    WStable public wUSR;
    constructor() {
        vm.startPrank(owner);
        // wfrxUSD
        wfrxUSD = new WStable("wfrxUSD", "wfrxUSD", controlTower, AddrClassicERC20.TOKEN_FRXUSD, AddrERC4626.S_FRXUSD, owner);
        deal(address(AddrClassicERC20.TOKEN_FRXUSD), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_FRXUSD.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(owner, 100_000 ether, false);

        // wcrvUSD
        wcrvUSD = new WStable("wcrvUSD", "wcrvUSD", controlTower, AddrClassicERC20.TOKEN_CRVUSD, AddrERC4626.S_CRVUSD, owner);
        deal(address(AddrClassicERC20.TOKEN_CRVUSD), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_CRVUSD.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(owner, 100_000 ether, false);

        // wUSDE
        wUSDE = new WStable("wUSDE", "wUSDE", controlTower, AddrClassicERC20.TOKEN_USDE, AddrERC4626.S_USDE, owner);
        deal(address(AddrClassicERC20.TOKEN_USDE), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_USDE.approve(address(wUSDE), MAX_UINT);
        wUSDE.mint(owner, 100_000 ether, false);

        // wDOLA
        wDOLA = new WStable("wDOLA", "wDOLA", controlTower, AddrClassicERC20.TOKEN_DOLA, AddrERC4626.S_DOLA, owner);
        deal(address(AddrClassicERC20.TOKEN_DOLA), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_DOLA.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(owner, 100_000 ether, false);

        // wUSR
        wUSR = new WStable("wUSR", "wUSR", controlTower, AddrClassicERC20.TOKEN_USR, AddrERC4626.WST_USR, owner);
        deal(address(AddrClassicERC20.TOKEN_USR), owner, 100_000 ether);
        AddrClassicERC20.TOKEN_USR.approve(address(wUSR), MAX_UINT);
        wUSR.mint(owner, 100_000 ether, false);
        vm.stopPrank();

        LpDeploymentContext.CreateTgUSDLpStruct[] memory params = new LpDeploymentContext.CreateTgUSDLpStruct[](5);
        params[0] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: wfrxUSD, name: "tgUSD-wfrxUSD", symbol: "tgfrxUSD", initialAmount: 5_000});
        params[1] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: wcrvUSD, name: "tgUSD-wcrvUSD", symbol: "tgcrvUSD", initialAmount: 5_000});
        params[2] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: wUSDE, name: "tgUSD-wUSDE", symbol: "tgUSDE", initialAmount: 5_000});
        params[3] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: wDOLA, name: "tgUSD-wDOLA", symbol: "tgDOLA", initialAmount: 5_000});
        params[4] = LpDeploymentContext.CreateTgUSDLpStruct({otherStable: wUSR, name: "tgUSD-wUSR", symbol: "tgUSR", initialAmount: 5_000});
        lpDeploymentContext.createTgUSDLps(owner, params);
    }
}
