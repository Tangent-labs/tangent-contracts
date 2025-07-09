import {writeFileSync} from "fs";
import {CRV_DUO_USDC_crvUSD, CRV_DUO_USDe_USDC, CRV_DUO_USDT_crvUSD} from "defi-resources/build/ressources/lps/curve";
import {SDT_crvUSD_USDC_STRAT, SDT_crvUSD_USDT_GAUGE, SDT_crvUSD_USDT_STRAT} from "defi-resources/build/ressources/erc20/stakeDao";
import {CURVE_USDe_USDC_GAUGE} from "defi-resources/build/ressources/erc20/curve";
import {CRV_USD_LLAMA_VAULT} from "defi-resources/build/ressources/erc20/llamalend";

interface ActionRow {
    actionType: string;
    contractAddress: string;
    user: string;
    amount: string;
    additionalParams: string;
}

/**
 *
 * @param key ADD ALL POOLS/GAUGE/VAULTS NECESSARY
 * TO COVER AS MANY USE CASES AS POSSIBLE
 * @param actionType
 * @returns
 */
export function mappingMethod(key: string, actionType: string): string {
    switch (actionType.toLowerCase()) {
        case "depositcurvelp":
            switch (key) {
                case "USDe_USDC":
                    return CRV_DUO_USDe_USDC;
                case "USDC_crvUSD":
                    return CRV_DUO_USDC_crvUSD;
                case "USDT_crvUSD":
                    return CRV_DUO_USDT_crvUSD;
                default:
                    throw new Error(`Unknown key ${key} for depositCurveLP`);
            }
        case "depositcurvegauge":
        case "withdrawcurvegauge":
            switch (key) {
                case "USDe_USDC":
                    return CURVE_USDe_USDC_GAUGE;
                default:
                    throw new Error(`Unknown key ${key} for depositCurveGauge/withdrawCurveGauge`);
            }
        case "depositstakedao":
        case "withdrawstakedao":
            switch (key) {
                case "USDC_crvUSD":
                    return SDT_crvUSD_USDC_STRAT;
                case "USDT_crvUSD":
                    return SDT_crvUSD_USDT_STRAT;
                default:
                    throw new Error(`Unknown key ${key} for depositStakeDao/withdrawStakeDao`);
            }
        case "transferposition":
            switch (key) {
                case "USDe_USDC":
                    return CRV_DUO_USDe_USDC;
                case "USDT_crvUSD":
                    return SDT_crvUSD_USDT_GAUGE;
                default:
                    throw new Error(`Unknown key ${key} for transferPosition`);
            }
        case "depositllamalend":
            switch (key) {
                case "CRV_USD":
                    return CRV_USD_LLAMA_VAULT;
                default:
                    throw new Error(`Unknown key ${key} for depositLlamaLend`);
            }
        case "withdrawcurvelp":
            switch (key) {
                case "USDT_crvUSD":
                    return CRV_DUO_USDT_crvUSD;
                default:
                    throw new Error(`Unknown key ${key} for withdrawCurveLP`);
            }
        default:
            throw new Error(`Unknown action type ${actionType} in mappingMethod`);
    }
}

class BlockchainScriptGenerator {
    sheetId: string;
    gid: string;
    variableCounter: number = 0;
    variableMap: Map<string, string> = new Map();
    latestLpVariable: string | null = null;

    constructor(sheetId: string, gid: string) {
        this.sheetId = sheetId;
        this.gid = gid;
    }

    async getCsv(): Promise<string> {
        const url = `https://docs.google.com/spreadsheets/d/${this.sheetId}/export?format=csv&gid=${this.gid}`;
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`HTTP Error: ${response.status}`);
        }
        return await response.text();
    }

    parseCsv(csvData: string): ActionRow[] {
        const rows = csvData.split("\n").map((row) => row.split(","));
        const headers = rows[0];

        const expectedHeaders = ["Action Type", "Contract Address", "User", "Amount", "Additional Params", "Comment"];
        if (!headers.every((h, i) => h.trim() === expectedHeaders[i])) {
            throw new Error("Invalid CSV headers");
        }

        return rows
            .slice(1)
            .map((row) => ({
                actionType: row[0]?.trim() || "",
                contractAddress: row[1]?.trim() || "",
                user: row[2]?.trim() || "",
                amount: row[3]?.trim() || "",
                additionalParams: row[4]?.trim() || "",
            }))
            .filter((row) => row.actionType !== "");
    }

    generateVariableName(contractAddress: string): string {
        const variableName = `lpToken${this.variableCounter++}`;
        this.variableMap.set(contractAddress, variableName);
        this.latestLpVariable = variableName;
        return variableName;
    }

    generateActionCode(row: ActionRow): string {
        const amount = row.amount && !["lpBalance"].includes(row.amount) ? `BigInt(${row.amount})` : row.amount;
        const contractAddress = row.contractAddress ? `mappingMethod("${row.contractAddress}", "${row.actionType}")` : '""';

        switch (row.actionType.toLowerCase()) {
            case "depositcurvelp": {
                const variableName = this.generateVariableName(row.contractAddress);
                return `
                    const ${variableName} = await depositCurveLP(${contractAddress}, ${row.additionalParams ? `BigInt(${row.additionalParams})` : "0n"}, ${amount}, ${row.user});
                `;
            }
            case "depositcurvegauge": {
                if (!this.latestLpVariable) {
                    throw new Error(`No LP token variable available for depositCurveGauge with key ${row.contractAddress}`);
                }
                return `
                    await depositCurveGauge(${contractAddress}, ${this.latestLpVariable}, ${row.user}, ${amount});
                `;
            }
            case "withdrawcurvegauge":
                return `
                    await withdrawCurveGauge(${contractAddress}, ${row.user}, ${amount});
                `;
            case "transferposition":
                return `
                    await context.transferPosition(${contractAddress}, ${row.user}, ${row.additionalParams ? `${row.additionalParams}.address` : '""'}, ${amount});
                `;
            case "advancetime":
                return `
                    await context.advanceTime(${row.amount});
                `;
            case "depositstakedao": {
                if (!this.latestLpVariable) {
                    throw new Error(`No LP token variable available for depositStakeDao with key ${row.contractAddress}`);
                }
                return `
                    await depositStakeDao(${this.latestLpVariable}, ${contractAddress}, ${row.user}, ${amount});
                `;
            }
            case "withdrawstakedao":
                return `
                    await withdrawStakeDao(${contractAddress}, ${row.user}, ${amount});
                `;
            case "depositllamalend":
                return `
                    await depositLlamaLend(${contractAddress}, ${row.additionalParams ? row.additionalParams : '""'}, ${row.user}, ${row.amount}, ${amount});
                `;
            case "withdrawcurvelp": {
                if (!this.latestLpVariable) {
                    throw new Error(`No LP token variable available for withdrawCurveLP with key ${row.contractAddress}`);
                }
                return `
                    const lpBalance = await ${this.latestLpVariable}.balanceOf(${row.user});
                    await withdrawCurveLP(${contractAddress}, lpBalance, ${row.user});
                `;
            }
            default:
                throw new Error(`Unknown action type: ${row.actionType}`);
        }
    }

    generateScriptContent(actions: ActionRow[]): string {
        return `
import { depositCurveLP } from '../actions/depositCurveLP';
import { depositStakeDao } from '../actions/depositStakeDao';
import { depositLlamaLend } from '../actions/depositLlamaLend';
import { withdrawCurveLP } from '../actions/withdrawCurveLP';
import { withdrawStakeDao } from '../actions/withdrawStakeDao';
import { depositCurveGauge } from '../actions/depositCurveGauge';
import { withdrawCurveGauge } from '../actions/withdrawCurveGauge';
import { crvUSD } from 'defi-resources/build/ressources/erc20/common';
import { PointsContext } from '../contexts/PointsContext';
import { mappingMethod } from './userActionGenerator';

export async function executeGeneratedActions(context: PointsContext): Promise<void> {
    try {
        const user1 = context.getUser1();
        const user2 = context.getUser2();
        if (!user1 || !user2) {
            throw new Error("Users not initialized. Call initUsers first.");
        }
${actions.map((action) => this.generateActionCode(action)).join("\n\n")}
    } catch (error) {
        throw error;
    }
}
        `;
    }

    async generateScript(): Promise<void> {
        console.log("CALL generateScript");

        try {
            const csvData = await this.getCsv();
            const actions = this.parseCsv(csvData);

            if (actions.length === 0) {
                throw new Error("No valid actions found in CSV");
            }

            const scriptContent = this.generateScriptContent(actions);
            writeFileSync("js-scripts/hardhat/USG/scripts/campaignActions.ts", scriptContent);
            console.log("Script generated successfully: js-scripts/hardhat/USG/scripts/campaignActions.ts");
        } catch (error) {
            console.error("Error generating script:", error);
            throw error;
        }
    }
}

async function main() {
    console.log("CALL MAIN IN userActionGenerator.ts");

    const generator = new BlockchainScriptGenerator("14kY9R4FzMriJ_vo-rt5yISM0pFIMJdkklcEf-wAlG70", "0");
    await generator.generateScript();
}

main().catch(console.error);
