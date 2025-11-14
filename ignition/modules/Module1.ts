import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { PROD_ADDRESSES } from "../prod_addresses";
import { commonERC20 } from "@tangent/defi-resources";

export default buildModule("Module1", (m) => {
    const controlTower = m.contract("ControlTower", [PROD_ADDRESSES.OWNER, PROD_ADDRESSES.FEE_TRESO]);
    const usg = m.contract("USG", [PROD_ADDRESSES.OWNER, controlTower]);

    const zappingProxy = m.contract("ZappingProxy", [PROD_ADDRESSES.OWNER]);


    const marketCvxCrvImplem = m.contract("ConvexCrvLPMarket", []);
    const marketCvxFxnImplem = m.contract("ConvexFxnLPMarket", []);
    const marketBasicER20Implem = m.contract("BasicERC20Market", []);

    const wcrvUSD = m.contract("WStable", ["Tangent Wrapped crvUSD", "wcrvUSD", controlTower, commonERC20.crvUSD, commonERC20.scrvUSD, PROD_ADDRESSES.OWNER], { id: "wcrvUSD" });
    const wUSDe = m.contract("WStable", ["Tangent Wrapped USDe", "wUSDe", controlTower, commonERC20.USDe, commonERC20.sUSDe, PROD_ADDRESSES.OWNER], { id: "wUSDe" });
    const wDOLA = m.contract("WStable", ["Tangent Wrapped DOLA", "wDOLA", controlTower, commonERC20.DOLA, commonERC20.sDOLA, PROD_ADDRESSES.OWNER], { id: "wDOLA" });
    const wUSR = m.contract("WStable", ["Tangent Wrapped USR", "wUSR", controlTower, commonERC20.USR, commonERC20.wstETH, PROD_ADDRESSES.OWNER], { id: "wUSR" });


    return { controlTower, zappingProxy, usg, marketCvxCrvImplem, marketCvxFxnImplem, marketBasicER20Implem, wcrvUSD, wUSDe, wDOLA, wUSR };
});