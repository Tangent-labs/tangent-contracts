import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { PROD_ADDRESSES } from "../prod_addresses";
import { COMMON_ERC20S } from "@tangent/defi-resources";

export default buildModule("Module1", (m) => {
    const controlTower = m.contract("ControlTower", [PROD_ADDRESSES.OWNER, PROD_ADDRESSES.FEE_TRESO]);
    const usg = m.contract("USG", [PROD_ADDRESSES.OWNER, controlTower]);

    const zappingProxy = m.contract("ZappingProxy", [PROD_ADDRESSES.OWNER]);


    const marketCvxCrvImplem = m.contract("ConvexCrvLPMarket", []);
    const marketCvxFxnImplem = m.contract("ConvexFxnLPMarket", []);
    const marketBasicER20Implem = m.contract("BasicERC20Market", []);

    const wcrvUSD = m.contract("WStable", ["Tangent Wrapped crvUSD", "wcrvUSD", controlTower, COMMON_ERC20S.crvUSD, COMMON_ERC20S.scrvUSD, PROD_ADDRESSES.OWNER], { id: "wcrvUSD" });
    const wUSDe = m.contract("WStable", ["Tangent Wrapped USDe", "wUSDe", controlTower, COMMON_ERC20S.USDe, COMMON_ERC20S.sUSDe, PROD_ADDRESSES.OWNER], { id: "wUSDe" });
    const wDOLA = m.contract("WStable", ["Tangent Wrapped DOLA", "wDOLA", controlTower, COMMON_ERC20S.DOLA, COMMON_ERC20S.sDOLA, PROD_ADDRESSES.OWNER], { id: "wDOLA" });
    const wUSR = m.contract("WStable", ["Tangent Wrapped USR", "wUSR", controlTower, COMMON_ERC20S.USR, COMMON_ERC20S.wstETH, PROD_ADDRESSES.OWNER], { id: "wUSR" });


    return { controlTower, zappingProxy, usg, marketCvxCrvImplem, marketCvxFxnImplem, marketBasicER20Implem, wcrvUSD, wUSDe, wDOLA, wUSR };
});