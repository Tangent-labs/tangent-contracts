import { RCParamsStruct } from "../../../../typechain-types/src/USG/Utilities/MarketCreator";

export const RC_PARAMS_LEC_USD_S_A_B: RCParamsStruct = {
    harvestFeePercentage: 500,
    startCutPercentage: 2500,
    endCutPercentage: 0,
    stepAmount: 1,
    startCutPrice: 1_000_000,
    endCutPrice: 980_000,
};


export const RC_PARAMS_HEC_USD_BASE: RCParamsStruct = {
    harvestFeePercentage: 500,
    startCutPercentage: 50_000,
    endCutPercentage: 100_000,
    stepAmount: 6,
    startCutPrice: 999_000,
    endCutPrice: 995_000,
};

export const RC_PARAMS_LEC_VOL: RCParamsStruct = {
    harvestFeePercentage: 500,
    startCutPercentage: 2_500,
    endCutPercentage: 0,
    stepAmount: 1,
    startCutPrice: 1_000_000,
    endCutPrice: 980_000,
};

export const RC_PARAMS_HEC_VOL: RCParamsStruct = {
    harvestFeePercentage: 500,
    startCutPercentage: 50_000,
    endCutPercentage: 100_000,
    stepAmount: 6,
    startCutPrice: 999_000,
    endCutPrice: 995_000,
};