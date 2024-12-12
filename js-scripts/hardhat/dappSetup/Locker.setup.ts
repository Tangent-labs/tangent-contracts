import {ethers} from "hardhat";

import {commonERC20, convexContracts, convexERC20, stakeDaoERC20} from "convergence-defi-tools";

import {ICvgCVX, ICvgSDT, ICVX1, ICvxStaking, IERC20, IGauge, ISdtStaking, ISdtUtilities} from "../../typechain-types";
import {MainSetup} from "../Main.setup";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {ZeroAddress} from "ethers";

export class LockerSetup extends MainSetup {
    private sdtUtilities!: ISdtUtilities;

    private sdt!: IERC20;
    private cvgSDT!: ICvgSDT;
    private cvgSDTStaking!: ISdtStaking;

    private cvx!: IERC20;
    private cvgCVX!: ICvgCVX;
    private CVX1!: ICVX1;
    private cvgCVXStaking!: ICvxStaking;

    async setupContracts() {
        this.sdtUtilities = await ethers.getContractAt("ISdtUtilities", "0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04");

        this.sdt = await ethers.getContractAt("IERC20", commonERC20.SDT);
        this.cvgSDT = await ethers.getContractAt("ICvgSDT", commonERC20.cvgSDT);
        this.cvgSDTStaking = await ethers.getContractAt("ISdtStaking", "0xf941bc649ef0b20abd7f6dc78ca8f8e225337933");

        this.cvx = await ethers.getContractAt("IERC20", commonERC20.CVX);
        this.cvgCVX = await ethers.getContractAt("ICvgCVX", convexERC20.cvgCVX);
        this.CVX1 = await ethers.getContractAt("ICVX1", convexERC20.CVX1);
        this.cvgCVXStaking = await ethers.getContractAt("ICvxStaking", "0x2c1d293c50c6d1a4370ebb442a02c5956bbab119");
    }

    splitArrayInTwo<T>(arr: T[]) {
        const midpoint = Math.ceil(arr.length / 2); // Get the midpoint (round up if odd length)
        const firstHalf = arr.slice(0, midpoint); // Slice from the start to the midpoint
        const secondHalf = arr.slice(midpoint); // Slice from the midpoint to the end

        return [firstHalf, secondHalf];
    }

    async stake() {
        const [usersNoStaking, usersStaking] = this.splitArrayInTwo(this.users);
        for (let i = 0; i < usersNoStaking.length; i++) {
            // StakeDao
            await this.approveAndMintLockers(this.users[i]);
        }

        for (let i = 0; i < usersStaking.length; i++) {
            // StakeDao
            const user = this.users[i];
            await this.approveAndMintLockers(user);

            await this.cvgSDT.connect(user).approve(this.cvgSDTStaking, ethers.parseEther("1000"));
            await this.cvgSDTStaking.connect(user).deposit(0, ethers.parseEther("1000"), ZeroAddress);

            await this.cvgCVX.connect(user).approve(this.cvgCVXStaking, ethers.parseEther("1000"));
            await this.cvgCVXStaking.connect(user).deposit(ethers.parseEther("1000"), 0, 0, 0, false);
        }
    }

    async approveAndMintLockers(user: HardhatEthersSigner) {
        // StakeDao

        await this.sdt.connect(user).approve(this.cvgSDT, this.erc20Minted);
        await this.cvgSDT.connect(user).mint(user, ethers.parseEther("1000"));

        // Convex

        await this.cvx.connect(user).approve(this.cvgCVX, this.erc20Minted);
        await this.cvx.connect(user).approve(this.CVX1, this.erc20Minted);

        await this.cvgCVX.connect(user).mint(user, ethers.parseEther("1000"), true);
        await this.CVX1.connect(user).mint(user, ethers.parseEther("1000"));
    }
}
