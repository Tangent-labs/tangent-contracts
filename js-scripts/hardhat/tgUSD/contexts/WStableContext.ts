import {ethers} from "hardhat";
import {WStable} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {MaxUint256} from "ethers";

export class WStablesContext {
    wStable: {[key: string]: WStable} = {};

    async deployWStables(baseContext: BaseContext) {
        const wStableFactory = await ethers.getContractFactory("WStable");
        const amount = ethers.parseEther("500000");

        const wfrxUSD = "wfrxUSD";
        const wfrxUSDContract = await wStableFactory.deploy(wfrxUSD, wfrxUSD, baseContext.controlTower, baseContext.coins.frxUSD, baseContext.coins.sfrxUSD, baseContext.owner);
        this.wStable[wfrxUSD] = wfrxUSDContract;
        await baseContext.coins.frxUSD.connect(baseContext.owner).approve(wfrxUSDContract, MaxUint256);
        await wfrxUSDContract.connect(baseContext.owner).mint(amount, baseContext.owner, false);

        const wcrvUSD = "wcrvUSD";
        const wcrvUSDContract = await wStableFactory.deploy(wcrvUSD, wcrvUSD, baseContext.controlTower, baseContext.coins.crvUSD, baseContext.coins.scrvUSD, baseContext.owner);
        this.wStable[wcrvUSD] = wcrvUSDContract;
        // await baseContext.coins.crvUSD.connect(baseContext.owner).approve(wcrvUSDContract, MaxUint256);
        // await wcrvUSDContract.connect(baseContext.owner).mint(amount, baseContext.owner, false);

        const wUSDE = "wUSDe";
        const wUSDEContract = await wStableFactory.deploy(wUSDE, wUSDE, baseContext.controlTower, baseContext.coins.USDe, baseContext.coins.sUSDe, baseContext.owner);
        this.wStable[wUSDE] = wUSDEContract;
        // await baseContext.coins.USDe.connect(baseContext.owner).approve(wUSDEContract, MaxUint256);
        // await wUSDEContract.connect(baseContext.owner).mint(amount, baseContext.owner, false);

        const wDOLA = "wDOLA";
        const wDOLAContract = await wStableFactory.deploy(wDOLA, wDOLA, baseContext.controlTower, baseContext.coins.DOLA, baseContext.coins.sDOLA, baseContext.owner);
        this.wStable[wDOLA] = wDOLAContract;
        // await baseContext.coins.DOLA.connect(baseContext.owner).approve(wDOLAContract, MaxUint256);
        // await wDOLAContract.connect(baseContext.owner).mint(amount, baseContext.owner, false);

        const wUSR = "wUSR";
        const wUSRContract = await wStableFactory.deploy(wUSR, wUSR, baseContext.controlTower, baseContext.coins.USR, baseContext.coins.wstUSR, baseContext.owner);
        this.wStable[wUSR] = wUSRContract;
        // await baseContext.coins.USR.connect(baseContext.owner).approve(wUSRContract, MaxUint256);
        // await wUSRContract.connect(baseContext.owner).mint(amount, baseContext.owner, false);

        for (const key in this.wStable) {
            const wStable = this.wStable[key];
            const stable = await ethers.getContractAt("ERC20", await wStable.stable());
            const saving = await ethers.getContractAt("ERC20", await wStable.savingAccount());

            for (let i = 0; i < baseContext.users.length; i++) {
                const user = baseContext.users[i];
                await stable.connect(user).approve(wStable, MaxUint256);
                await saving.connect(user).approve(wStable, MaxUint256);
            }
        }
    }
}
