import { COMMON_ERC20S, CURVE_LPS } from "@tangent/defi-resources";
import { SDT_BOLD_USDC_VAULT, SDT_crvUSD_USDT_VAULT, SDT_ETHPlus_WETH_VAULT, SDT_eUSD_USDC_VAULT, SDT_frxUSD_OUSD_VAULT, SDT_frxUSD_scrvUSD_VAULT, SDT_frxUSD_sDOLA_VAULT, SDT_frxUSD_sUSDS_VAULT, SDT_reUSD_scrvUSD_VAULT, SDT_tBTC_cbBTC_VAULT } from "@tangent/defi-resources/build/ressources/erc20/stakeDao";
import { parseEther } from "ethers";
import { IR_PARAMS_HEC_USD_S, IR_PARAMS_HEC_VOL, IR_PARAMS_LEC_USD_A, IR_PARAMS_LEC_USD_B, IR_PARAMS_LEC_USD_S, IR_PARAMS_LEC_VOL } from "../irParams";
import { MINIMUM_LOAN } from "../market";
import { RC_PARAMS_HEC_USD_BASE, RC_PARAMS_HEC_VOL, RC_PARAMS_LEC_USD_S_A_B, RC_PARAMS_LEC_VOL } from "../rcParams";

export const STATIC_CONFIG_STAKEDAO_VAULT_V2 = {

    // PROD
    frxUSD_sUSDS: {
        collatName: "frxUSD/sUSDS",
        collatToken: CURVE_LPS.DUO_frxUSD_sUSDS,
        liquidationThreshold: 91_250,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.WFRAX],
        vaultToken: SDT_frxUSD_sUSDS_VAULT,
        irConfig: IR_PARAMS_LEC_USD_S,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },
    BOLD_USDC: {
        collatName: "BOLD/USDC",
        collatToken: CURVE_LPS.DUO_BOLD_USDC,
        liquidationThreshold: 91_250,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.BOLD],
        vaultToken: SDT_BOLD_USDC_VAULT,
        irConfig: IR_PARAMS_LEC_USD_A,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },

    eUSD_USDC: {
        collatName: "eUSD/USDC",
        collatToken: CURVE_LPS.DUO_eUSD_USDC,
        liquidationThreshold: 88_750,
        maxLTV: 87_500,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_eUSD_USDC_VAULT,
        irConfig: IR_PARAMS_HEC_USD_S,
        rcConfig: RC_PARAMS_HEC_USD_BASE
    },


    reUSD_scrvUSD: {
        collatName: "reUSD/scrvUSD",
        collatToken: CURVE_LPS.DUO_reUSD_scrvUSD,
        liquidationThreshold: 85_250,
        maxLTV: 84_000,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_reUSD_scrvUSD_VAULT,
        irConfig: IR_PARAMS_LEC_USD_B,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },

    USDT_crvUSD: {
        collatName: "USDT/crvUSD",
        collatToken: CURVE_LPS.DUO_USDT_crvUSD,
        liquidationThreshold: 85_250,
        maxLTV: 84_000,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_crvUSD_USDT_VAULT,
        irConfig: IR_PARAMS_LEC_USD_B,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },
    frxUSD_OUSD: {
        collatName: "frxUSD/OUSD",
        collatToken: CURVE_LPS.DUO_frxUSD_OUSD,
        liquidationThreshold: 88_750,
        maxLTV: 87_500,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_frxUSD_OUSD_VAULT,
        irConfig: IR_PARAMS_HEC_USD_S,
        rcConfig: RC_PARAMS_HEC_USD_BASE
    },
    frxUSD_sDOLA: {
        collatName: "frxUSD/sDOLA",
        collatToken: CURVE_LPS.DUO_frxUSD_sDOLA,
        liquidationThreshold: 85_250,
        maxLTV: 84_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_frxUSD_sDOLA_VAULT,
        irConfig: IR_PARAMS_HEC_USD_S,
        rcConfig: RC_PARAMS_HEC_USD_BASE
    },
    frxUSD_scrvUSD: {
        collatName: "frxUSD/scrvUSD",
        collatToken: CURVE_LPS.DUO_frxUSD_scrvUSD,
        liquidationThreshold: 85_250,
        maxLTV: 84_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_frxUSD_scrvUSD_VAULT,
        irConfig: IR_PARAMS_LEC_USD_B,
        rcConfig: RC_PARAMS_HEC_USD_BASE
    },
    tBTC_cbBTC: {
        collatName: "tBTC/cbBTC",
        collatToken: CURVE_LPS.DUO_tBTC_cbBTC,
        liquidationThreshold: 82_000,
        maxLTV: 78_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_tBTC_cbBTC_VAULT,
        irConfig: IR_PARAMS_LEC_VOL,
        rcConfig: RC_PARAMS_LEC_VOL
    },
    "ETH+_WETH": {
        collatName: "ETH+/WETH",
        collatToken: CURVE_LPS.DUO_ETHplus_WETH,
        liquidationThreshold: 76_000,
        maxLTV: 72_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: SDT_ETHPlus_WETH_VAULT,
        irConfig: IR_PARAMS_LEC_VOL,
        rcConfig: RC_PARAMS_LEC_VOL
    },
    msETH_WETH: {
        collatName: "msETH/WETH",
        collatToken: CURVE_LPS.DUO_msETH_WETH,
        liquidationThreshold: 76_000,
        maxLTV: 72_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: "0x7053FA875C478045124CE3Ef740a189b6037DF91",
        irConfig: IR_PARAMS_HEC_VOL,
        rcConfig: RC_PARAMS_HEC_VOL
    }
};
