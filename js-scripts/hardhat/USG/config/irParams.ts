import { IRParamsStruct } from "../../../../typechain-types/src/USG/Utilities/IRCalculator";

export const IR_PARAMS_LEC_USD_S: IRParamsStruct = {
    isHEC: false,
    rMin: 3_198,
    rMax: 109_861,
    pMin: 980_000,
    pInf: 985_000,
    pMax: 1_000_000,
    a1: 1000,
    a2: 2075,
    k: 1_225,
};

export const IR_PARAMS_LEC_USD_A: IRParamsStruct = {
    isHEC: false,
    rMin: 3_198,
    rMax: 109_861,
    pMin: 980_000,
    pInf: 989_300,
    pMax: 1_000_000,
    a1: 1000,
    a2: 2075,
    k: 1_225,
};

export const IR_PARAMS_LEC_USD_B: IRParamsStruct = {
    isHEC: false,
    rMin: 3_198,
    rMax: 109_861,
    pMin: 980_000,
    pInf: 990_250,
    pMax: 1_000_000,
    a1: 1000,
    a2: 2075,
    k: 1_225,
};

export const IR_PARAMS_HEC_USD_S: IRParamsStruct = {
    isHEC: true,
    rMin: 3_198,
    rMax: 109_861,
    pMin: 980_000,
    pInf: 990_000,
    pMax: 995000,
    a1: 600,
    a2: 2300,
    k: 50,
};