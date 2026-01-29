import { writeFileSync } from "fs";

interface ActionRow {
    actionType: string;
    key: string;
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

        const expectedHeaders = ["Action Type", "Contract Address", "User", "Amount", "Additional Params"];
        if (!headers.every((h, i) => h.trim().replace("\r", "") === expectedHeaders[i])) {
            throw new Error("Invalid CSV headers");
        }

        return rows
            .slice(1)
            .map((row) => ({
                actionType: row[0]?.trim() || "",
                key: row[1]?.trim() || "",
                user: row[2]?.trim() || "",
                amount: row[3]?.trim() || "",
                additionalParams: row[4]?.trim() || "",
            }))
            .filter((row) => row.actionType !== "");
    }

    generateVariableName(key: string): string {
        const variableName = `lpToken${this.variableCounter++}`;
        this.variableMap.set(key, variableName);
        this.latestLpVariable = variableName;
        return variableName;
    }

    generateActionCode(row: ActionRow): string {
        const params = `"${row.key}", ${row.user}, ${row.amount}`;
        const compositBorrowParams = `"${row.key}", ${row.user}, ${row.amount}, ${row.additionalParams}`;
        const transferParams = `"${row.key}", ${row.user}, ${row.additionalParams}, ${row.amount}`;

        const actionType = row.actionType;
        if (actionType.includes("transfer") || actionType === "repayUSG") {
            return `await ${actionType}(${transferParams});`;
        } else if (actionType === "timeTravel") {
            return `await timeTravel(${row.amount});`;
        } else if (["depositAndBorrowUSG", "repayUSGAndWithdraw", "voteOnGauge"].includes(actionType)) {
            return `await ${actionType}(${compositBorrowParams});`;
        } else {
            return `await ${actionType}(${params});`;
        }
    }

    generateScriptContent(actions: ActionRow[]): string {
        return `
import { ethers } from "hardhat";
import { giveTokensToAddresses } from "../../thief/thief";
import { timeTravel } from "../actions/time-travel";
import { depositCurveLP, withdrawCurveLP, depositCurveGauge, withdrawCurveGauge, depositStakeDao, withdrawStakeDao, depositConvex, withdrawConvex, depositLlamaLend, withdrawLlamaLend, transferCurveLP, transferCurveGauge, transferStakeDaoGauge } from '../actions/curveEcoActions';
import { pendleDepositPTAndYT, pendleDepositLP, pendleWithdrawLP, pendleWithdrawPT, pendleWithdrawYT, pendleDepositLPRouter, pendleDepositPTRouter, pendleDepositYTRouter, pendleWithdrawLPRouter} from "../actions/pendleActions";
import { borrowUSG, repayUSG, depositAndBorrowUSG, repayUSGAndWithdraw } from "../actions/usgActions";
import { voteOnGauge } from "../actions/vote-on-gauge";

main();
export async function main() {

    const FXN = "FXN";
    const CRV = "CRV";
    try {
        const [user0, user1, user2, user3, user4, user5, user6, user7, user8, user9] = await ethers.getSigners();

${actions.map((action) => this.generateActionCode(action)).join("\n\n")}
    } catch (error) {
        throw error;
    }
}`;
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
            writeFileSync("js-scripts/hardhat/USG/scripts/generated-actions.ts", scriptContent);
            console.log("Script generated successfully: js-scripts/hardhat/USG/scripts/generated-actions.ts");
        } catch (error) {
            console.error("Error generating script:", error);
            throw error;
        }
    }
}

async function main() {
    const generator = new BlockchainScriptGenerator("14kY9R4FzMriJ_vo-rt5yISM0pFIMJdkklcEf-wAlG70", "25851155");
    await generator.generateScript();
}

main().catch(console.error);
