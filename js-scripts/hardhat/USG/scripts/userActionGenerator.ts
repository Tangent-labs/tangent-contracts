import {writeFileSync} from "fs";

interface ActionRow {
    actionType: string;
    contractAddress: string;
    user: string;
    amount: string;
    additionalParams: string;
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

        switch (row.actionType.toLowerCase()) {
            case "depositcurvelp":
                return `await depositCurveLP("${row.contractAddress}", ${row.user}, ${amount});`;
            case "depositcurvegauge":
                return `await depositCurveGauge("${row.contractAddress}", ${row.user}, ${amount});`;
            case "withdrawcurvegauge":
                return `await withdrawCurveGauge("${row.contractAddress}", ${row.user}, ${amount});`;
            case "transferposition":
                return `await context.transferPosition("${row.contractAddress}", ${row.user}, ${row.additionalParams ? `${row.additionalParams}.address` : '""'}, ${amount});`;
            case "advancetime":
                return `await context.advanceTime(${row.amount});`;
            case "depositstakedao":
                return `await depositStakeDao("${row.contractAddress}", ${row.user}, ${amount});`;
            case "withdrawstakedao":
                return `await withdrawStakeDao("${row.contractAddress}", ${row.user}, ${amount});`;
            case "depositllamalend":
                return `await depositLlamaLend("${row.contractAddress}", ${row.user}, ${row.amount}, ${amount});`;
            case "withdrawcurvelp":
                return `await withdrawCurveLP("${row.contractAddress}", ${amount}, ${row.user});`;
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
import { PointsContext } from '../contexts/PointsContext';

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
