import {ethers} from "hardhat";

import {commonERC20, stakeDaoERC20, thiefConfig} from "defi-resources";

import {IERC20, IGauge, ISdtStaking, ISdtUtilities} from "../../typechain-types";
import {MainSetup} from "../Main.setup";
import {ICvgCvxStakingPositionService, ICycleProcessor, ISdtBuffer} from "../../../typechain-types";
import {parseEther, Signer} from "ethers";

import {cvgCVX} from "defi-resources/build/ressources/erc20/convex";
import {giveTokenToAddresss} from "../thief/thief";
import {safeApprove} from "../USG/actions/safeApprove";
import {getSlot} from "../thief/slotGuesser";

export class BoosterSetup extends MainSetup {
    private sdtUtilities!: ISdtUtilities;

    private CRV!: IERC20;
    private PENDLE!: IERC20;
    private FXN!: IERC20;
    private _80Bal_20ETH!: IERC20;

    private sdCRV!: IERC20;
    private sdPENDLE!: IERC20;
    private sdFXN!: IERC20;
    private sdBAL!: IERC20;
    public cvgSDT!: IERC20;
    public cvgCVX!: IERC20;

    private sdCRVGauge!: IGauge;
    private sdPENDLEGauge!: IGauge;
    private sdFXNGauge!: IGauge;
    private sdBALGauge!: IGauge;

    SD_CRV_STAKING!: ISdtStaking;
    SD_PENDLE_STAKING!: ISdtStaking;
    SD_FXN_STAKING!: ISdtStaking;
    SD_BAL_STAKING!: ISdtStaking;
    CVG_SDT_STAKING!: ISdtStaking;
    SD_CVG_CVX_STAKING!: ISdtStaking;
    CVG_CVX_STAKING!: ICvgCvxStakingPositionService;

    sdCrvBuffer!: ISdtBuffer;
    sdPendleBuffer!: ISdtBuffer;
    sdFxnBuffer!: ISdtBuffer;
    sdBalBuffer!: ISdtBuffer;
    cvgSDTBuffer!: ISdtBuffer;
    //cvgCvxStakingService!: ICvgCvxStakingPositionService;
    cycleProcessor!: ICycleProcessor;

    cvgCVXAddress = "0x2191DF768ad71140F9F3E96c1e4407A4aA31d082";

    async giveSpecificTokens() {
        //console.log(await getSlot([{address: this.cvgCVXAddress, isVyper: false}]));

        const THIEF_TOKEN_CONFIG = thiefConfig.THIEF_TOKEN_CONFIG;
        
        const tokens = ["cvgCVX", "cvgSDT", "SDT", "CRV", "PENDLE", "FXN", "BAL", "sd_CRV", "sd_PENDLE", "sd_BAL", "sd_FXN"];
        await Promise.all(
            this.users?.map(async (user) => {
                tokens.map(async (token) => {
                    const tokenConfig = THIEF_TOKEN_CONFIG[token];
                    if (tokenConfig?.address) {
                        return giveTokenToAddresss(user, tokenConfig.address, ethers.parseEther("1000000000"), tokenConfig.slotBalance, tokenConfig.isVyper);
                    } else {
                        console.error(` token ${token} not found in THIEF_TOKEN_CONFIG`);
                        return new Promise((resolve) => resolve(null));
                    }
                });
            })
        );

        // give more tokens to user 8
        const signers = await ethers.getSigners();
        const user8 = signers[8];
        await giveTokenToAddresss(user8, commonERC20.SDT, ethers.parseEther("1000000000"), 0, false);
        await giveTokenToAddresss(user8, commonERC20.CRV, ethers.parseEther("1000000000"), 0, false);
        await giveTokenToAddresss(user8, commonERC20.PENDLE, ethers.parseEther("1000000000"), 0, false);
        await giveTokenToAddresss(user8, commonERC20.FXN, ethers.parseEther("1000000000"), 0, false);
        await giveTokenToAddresss(user8, commonERC20.BAL, ethers.parseEther("1000000000"), 0, false);
    }

    async setupContracts() {
        this.sdtUtilities = await ethers.getContractAt("ISdtUtilities", "0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04");
        this.CRV = await ethers.getContractAt("IERC20Metadata", commonERC20.CRV);
        this.sdCRV = await ethers.getContractAt("IERC20Metadata", stakeDaoERC20.sdCRV);
        this.sdCRVGauge = await ethers.getContractAt("IGauge", stakeDaoERC20.sdCRV_GAUGE);
        this.SD_CRV_STAKING = await ethers.getContractAt("ISdtStaking", "0x2FF160bcADb485b5F048b9880e6f471Af632060c");
        this.sdCrvBuffer = await ethers.getContractAt("ISdtBuffer", await this.SD_CRV_STAKING.buffer());

        this.PENDLE = await ethers.getContractAt("IERC20Metadata", commonERC20.PENDLE);
        this.sdPENDLE = await ethers.getContractAt("IERC20Metadata", stakeDaoERC20.sdPENDLE);
        this.sdPENDLEGauge = await ethers.getContractAt("IGauge", stakeDaoERC20.sdPENDLE_GAUGE);
        this.SD_PENDLE_STAKING = await ethers.getContractAt("ISdtStaking", "0x508f0E1b565b40AeB94671BeD228083203330882");
        this.sdPendleBuffer = await ethers.getContractAt("ISdtBuffer", await this.SD_PENDLE_STAKING.buffer());

        this.FXN = await ethers.getContractAt("IERC20Metadata", commonERC20.FXN);
        this.sdFXN = await ethers.getContractAt("IERC20Metadata", stakeDaoERC20.sdFXN);
        this.sdFXNGauge = await ethers.getContractAt("IGauge", stakeDaoERC20.sdFXN_GAUGE);
        this.SD_FXN_STAKING = await ethers.getContractAt("ISdtStaking", "0x35e30Bc815935Bb5EC1743f772331864D780cc26");
        this.sdFxnBuffer = await ethers.getContractAt("ISdtBuffer", await this.SD_FXN_STAKING.buffer());

        this._80Bal_20ETH = await ethers.getContractAt("IERC20Metadata", stakeDaoERC20._80BAL_20WETH);
        this.sdBAL = await ethers.getContractAt("IERC20Metadata", stakeDaoERC20.sdBAL);
        this.sdBALGauge = await ethers.getContractAt("IGauge", stakeDaoERC20.sdBAL_GAUGE);
        this.SD_BAL_STAKING = await ethers.getContractAt("ISdtStaking", "0xAf5b3f4A0b4dc334dB7137E5584E0e971E5e4962");
        this.sdBalBuffer = await ethers.getContractAt("ISdtBuffer", await this.SD_BAL_STAKING.buffer());

        this.cvgSDT = await ethers.getContractAt("IERC20Metadata", commonERC20.cvgSDT);
        this.CVG_SDT_STAKING = await ethers.getContractAt("ISdtStaking", "0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933");
        this.cvgSDTBuffer = await ethers.getContractAt("ISdtBuffer", await this.CVG_SDT_STAKING.buffer());

        this.cycleProcessor = await ethers.getContractAt("ICycleProcessor", "0x49d2de51f61e439d7e97810834e56ff0c4ce5c9b");

        //CvgCvxStakingService
        this.CVG_CVX_STAKING = await ethers.getContractAt("ICvgCvxStakingPositionService", "0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119");
        this.cvgCVX = await ethers.getContractAt("IERC20Metadata", this.cvgCVXAddress);
    }

    async stake() {
        const gaugeAmount = ethers.parseEther("1000");
        const erc20Minted = parseEther(this.erc20Minted.toString());
        for (let i = 0; i < this.users.length; i++) {
            const user = this.users[i];

            // CRV
            await this.sdCRV.connect(user).approve(this.sdCRVGauge, ethers.parseEther("10000"));
            await this.sdCRVGauge.connect(user).deposit(gaugeAmount);
            await this.sdCRV.connect(user).approve(this.sdtUtilities, erc20Minted);
            await this.sdCRVGauge.connect(user).approve(this.SD_CRV_STAKING, erc20Minted);
            await this.SD_CRV_STAKING.connect(user).deposit(0, ethers.parseEther("500"), user);
            await this.sdtUtilities.connect(user).convertAndStakeSdAsset(0, this.SD_CRV_STAKING, 0, 0, ethers.parseEther("500"), 0, false);

            // PENDLE
            await this.sdPENDLE.connect(user).approve(this.sdPENDLEGauge, ethers.parseEther("10000"));
            await this.sdPENDLEGauge.connect(user).deposit(ethers.parseEther("1000"));
            await this.sdPENDLE.connect(user).approve(this.sdtUtilities, erc20Minted);
            await this.sdtUtilities.connect(user).convertAndStakeSdAsset(0, this.SD_PENDLE_STAKING, 0, 0, ethers.parseEther("500"), 0, false);

            // FXN
            await this.sdFXN.connect(user).approve(this.sdFXNGauge, ethers.parseEther("10000"));
            await this.sdFXNGauge.connect(user).deposit(ethers.parseEther("1000"));
            await this.sdFXN.connect(user).approve(this.sdtUtilities, erc20Minted);
            await this.sdtUtilities.connect(user).convertAndStakeSdAsset(0, this.SD_FXN_STAKING, 0, 0, ethers.parseEther("500"), 0, false);

            // BAL
            await this.sdBAL.connect(user).approve(this.sdBALGauge, ethers.parseEther("10000"));
            await this.sdBALGauge.connect(user).deposit(ethers.parseEther("1000"));
            await this.sdBAL.connect(user).approve(this.sdtUtilities, erc20Minted);
            await this.sdtUtilities.connect(user).convertAndStakeSdAsset(0, this.SD_BAL_STAKING, 0, 0, ethers.parseEther("500"), 0, false);
        }
    }
}
