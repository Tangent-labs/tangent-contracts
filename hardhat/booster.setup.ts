import { giveTokensToAddresses } from "./thief";
import { ethers } from "hardhat";

import {
  thiefConfig,
  commonERC20,
  stakeDaoContracts,
  stakeDaoERC20,
  stakeDaoMapping,
} from "convergence-defi-tools";
import { sdCRV } from "convergence-defi-tools/ressources/erc20/stakeDao";
import { ZeroAddress } from "ethers";

async function main() {
  const users = await ethers.getSigners();
  const testUsers = [
    users[0],
    users[1],
    users[2],
    users[3],
    users[4],
    users[5],
    users[6],
  ];

  const mintedAmount = ethers.parseEther("100000");

  await giveTokensToAddresses(testUsers, [
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.CRV,
      amount: mintedAmount,
    },
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.sd_CRV,
      amount: mintedAmount,
    },

    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.PENDLE,
      amount: mintedAmount,
    },
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.sd_PENDLE,
      amount: mintedAmount,
    },

    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.BAL,
      amount: mintedAmount,
    },
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG._80_BAL_20_WETH,
      amount: mintedAmount,
    },
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.sd_BAL,
      amount: mintedAmount,
    },

    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.FXN,
      amount: mintedAmount,
    },
    {
      token: thiefConfig.THIEF_TOKEN_CONFIG.sd_FXN,
      amount: mintedAmount,
    },
  ]);

  const sdtUtilities = await ethers.getContractAt(
    "ISdtUtilities",
    "0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04"
  );

  const SD_CRV_STAKING = await ethers.getContractAt(
    "ISdtStaking",
    "0x2ff160bcadb485b5f048b9880e6f471af632060c"
  );
  const SD_BAL_STAKING = await ethers.getContractAt(
    "ISdtStaking",
    "0xaf5b3f4a0b4dc334db7137e5584e0e971e5e4962"
  );
  const SD_PENDLE_STAKING = await ethers.getContractAt(
    "ISdtStaking",
    "0x508f0e1b565b40aeb94671bed228083203330882"
  );
  const SD_FXN_STAKING = await ethers.getContractAt(
    "ISdtStaking",
    "0x35e30bc815935bb5ec1743f772331864d780cc26"
  );

  const crv = await ethers.getContractAt("IERC20", commonERC20.CRV);
  const sdCRV = await ethers.getContractAt("IERC20", stakeDaoERC20.sdCRV);
  const sdCRVGauge = await ethers.getContractAt(
    "IGauge",
    stakeDaoERC20.sdCRV_GAUGE
  );

  const pendle = await ethers.getContractAt("IERC20", commonERC20.PENDLE);
  const sdPENDLE = await ethers.getContractAt("IERC20", stakeDaoERC20.sdPENDLE);
  const sdPENDLEGauge = await ethers.getContractAt(
    "IGauge",
    stakeDaoERC20.sdPENDLE_GAUGE
  );

  const fxn = await ethers.getContractAt("IERC20", commonERC20.FXN);
  const sdFXN = await ethers.getContractAt("IERC20", stakeDaoERC20.sdFXN);
  const sdFXNGauge = await ethers.getContractAt(
    "IGauge",
    stakeDaoERC20.sdFXN_GAUGE
  );

  const _80Bal_20ETH = await ethers.getContractAt(
    "IERC20",
    stakeDaoERC20._80BAL_20WETH
  );
  const sdBAL = await ethers.getContractAt("IERC20", stakeDaoERC20.sdBAL);
  const sdBALGauge = await ethers.getContractAt(
    "IGauge",
    stakeDaoERC20.sdBAL_GAUGE
  );

  for (let i = 0; i < testUsers.length; i++) {
    const user = testUsers[i];

    // CRV

    await sdCRV.connect(user).approve(sdCRVGauge, ethers.parseEther("10000"));
    await sdCRVGauge.connect(user).deposit(ethers.parseEther("1000"));

    await crv.connect(user).approve(sdtUtilities, mintedAmount);
    await sdCRV.connect(user).approve(sdtUtilities, mintedAmount);
    await sdCRVGauge.connect(user).approve(SD_CRV_STAKING, mintedAmount);

    await SD_CRV_STAKING.connect(user).deposit(
      0,
      ethers.parseEther("500"),
      user
    );

    // PENDLE

    await pendle.connect(user).approve(sdtUtilities, mintedAmount);

    await SD_CRV_STAKING.connect(user).deposit(
      0,
      ethers.parseEther("500"),
      user
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
