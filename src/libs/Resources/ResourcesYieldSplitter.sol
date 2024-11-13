// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICvxRewardToken} from "../../interfaces/externals/Convex/ICvxRewardToken.sol";

import {IStakeDaoVault} from "../../interfaces/externals/StakeDao/IStakeDaoVault.sol";
import {ILlamaVault} from "../../interfaces/externals/LlamaLend/ILlamaVault.sol";
import {ISdtLiquidityGauge} from "../../interfaces/externals/StakeDao/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxRewardToken} from "../../interfaces/externals/Convex/ICvxRewardToken.sol";
import {ICrvUSDController} from "../../interfaces/externals/LlamaLend/ICrvUSDController.sol";

library AddrGlobal {
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address constant CURVE_ROUTER = 0x16C6521Dff6baB339122a0FE25a9116693265353;
    address constant CVX_VOTER_PROXY = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;
}

library AddrCrvController {
    ICrvUSDController constant CRVUSD_CRV = ICrvUSDController(0xEdA215b7666936DEd834f76f3fBC6F323295110A);
    ICrvUSDController constant CRVUSD_LEVERAGE_WETH = ICrvUSDController(0x23F5a668A9590130940eF55964ead9787976f2CC);
    ICrvUSDController constant CRVUSD_LEVERAGE_WBTC = ICrvUSDController(0xcaD85b7fe52B1939DCEebEe9bCf0b2a5Aa0cE617);
}

library AddrCrvAmm {
    address constant CRVUSD_CRV = 0xafca625321Df8D6A068bDD8F1585d489D2acF11b;
    address constant CRVUSD_LEVERAGE_WETH = 0x04b28CcF37828978140643525961D20099e63668;
    address constant CRVUSD_LEVERAGE_WBTC = 0x8eeDE294459EFaFf55d580bc95C98306Ab03F0C8;
}

library AddrCrvGauges {
    IERC20 constant CRVUSD_CRV = IERC20(0x49887dF6fE905663CDB46c616BfBfBB50e85a265);
    IERC20 constant CRVUSD_LEVERAGE_WETH = IERC20(0xF3F6D6d412a77b680ec3a5E35EbB11BbEC319739);
    IERC20 constant CRVUSD_LEVERAGE_WBTC = IERC20(0x7dCB252f7Ea2B8dA6fA59C79EdF63f793C8b63b6);
}

library AddrSdtGauges {
    //Stake DAO crvUSD Gauges
    ISdtLiquidityGauge constant CRVUSD_CRV = ISdtLiquidityGauge(0xFCc5a1B4e3d80Ce459e346A0b8F63b655ED709cb);
    ISdtLiquidityGauge constant CRVUSD_LEVERAGE_WETH = ISdtLiquidityGauge(0x070365950CeCfC0b6a1A4e635638fe51495bA2F2);
}

library AddrLlamaLendVaults {
    // LlamaLend crvUSD Vaults (cvcrvUSD)
    ILlamaVault constant CRVUSD_CRV = ILlamaVault(0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA);
    ILlamaVault constant CRVUSD_LEVERAGE_WETH = ILlamaVault(0x8fb1c7AEDcbBc1222325C39dd5c1D2d23420CAe3);
    ILlamaVault constant CRVUSD_LEVERAGE_WBTC = ILlamaVault(0xccd37EB6374Ae5b1f0b85ac97eFf14770e0D0063);
}

library AddrSdtVaults {
    //Stake DAO crvUSD Vaults
    //LEVERAGE
    IStakeDaoVault constant CRVUSD_LEVERAGE_WETH = IStakeDaoVault(0x09f139184d04789B963205c163C73F4beA468b95);
    IStakeDaoVault constant CRVUSD_LEVERAGE_USDE = IStakeDaoVault(0x4B9b73e6867048be63f949c653962F40CdAfF518);
    IStakeDaoVault constant CRVUSD_LEVERAGE_WSTETH = IStakeDaoVault(0x7Ef9B729DA3a67FC3b6C4088c17063D3df4EE72F);
    IStakeDaoVault constant CRVUSD_LEVERAGE_SFRAX = IStakeDaoVault(0x973Fbeb10d670B91a0b47059ddb0931c52D239Fd);
    IStakeDaoVault constant CRVUSD_LEVERAGE_PUFETH = IStakeDaoVault(0xf8d4bb9da194C4606A5eAecD26d79dE795603fB1);
    IStakeDaoVault constant CRVUSD_LEVERAGE_WBTC = IStakeDaoVault(0x8d95F82fD8Fb409A44997452a492BE31cf896744);
    IStakeDaoVault constant CRVUSD_LEVERAGE_SUSDE = IStakeDaoVault(0x64DAa88D2377706C5953F6bC606684F2037f0f78);
    IStakeDaoVault constant CRVUSD_LEVERAGE_SDOLA = IStakeDaoVault(0x2eB6af2F70fc14E324A5E326296708e7E9EbDfAb);
    //NORMAL
    IStakeDaoVault constant CRVUSD_CRV = IStakeDaoVault(0xfa6D40573082D797CB3cC378c0837fB90eB043e5);
    IStakeDaoVault constant CRVUSD_TBTC = IStakeDaoVault(0x57e94F41E596FC8315B20321156421c20CdC93f9);
    IStakeDaoVault constant CRVUSD_SUSDE = IStakeDaoVault(0xED2a17704bC5D5a7c5d256228333026B76A1732e);
    IStakeDaoVault constant CRVUSD_WETH = IStakeDaoVault(0xADde9073d897743E7004115Fa2452cC959FBF28a);
    IStakeDaoVault constant CRVUSD_WSTETH = IStakeDaoVault(0xbe3C3Fd181af6B99CC1bb9b0Ee065318aDFc4c96);
}

library AddrCvxRewardTokens {
    ICvxRewardToken constant CRVUSD_CRV = ICvxRewardToken(0x4bf2d8484474170bff8a8c34475be3d87dFF28cA);
    ICvxRewardToken constant CRVUSD_LEVERAGE_WETH = ICvxRewardToken(0xcE2E915Dd0530E66Cfc34b7421E9A93F09A9A6b5);
    ICvxRewardToken constant CRVUSD_TBTC = ICvxRewardToken(0x57e94F41E596FC8315B20321156421c20CdC93f9);
    ICvxRewardToken constant CRVUSD_SUSDE = ICvxRewardToken(0xED2a17704bC5D5a7c5d256228333026B76A1732e);
    ICvxRewardToken constant CRVUSD_WETH = ICvxRewardToken(0xADde9073d897743E7004115Fa2452cC959FBF28a);
    ICvxRewardToken constant CRVUSD_WSTETH = ICvxRewardToken(0xbe3C3Fd181af6B99CC1bb9b0Ee065318aDFc4c96);
    ICvxRewardToken constant CRVUSD_LEVERAGE_WBTC = ICvxRewardToken(0xfe382f1Bf78e6D6012cB38C284Fe123ec9821966);

    ICvxRewardToken constant CRVUSD_USDC_LP = ICvxRewardToken(0x44D8FaB7CD8b7877D5F79974c2F501aF6E65AbBA);
}

library AddrCvxVaultTokens {
    IERC20 constant CRVUSD_CRV = ICvxRewardToken(0xf0ac58AF1ca98aFce29fAe456E853688ab9d41E2);
    IERC20 constant CRVUSD_LEVERAGE_WETH = ICvxRewardToken(0xd6Ab4Ca1fb1D3993db4d37b04621D28B669b671E);
    IERC20 constant CRVUSD_LEVERAGE_WBTC = ICvxRewardToken(0xDF2Cf819DBC1E5a5774eE760D2678330cf4665e2);
}

library PidCvxBooster {
    //NORMAL
    uint256 constant CRVUSD_CRV = 325;
    uint256 constant CRVUSD_LEVERAGE_WETH = 365;
    uint256 constant CRVUSD_TBTC = 328;
    uint256 constant CRVUSD_SUSDE = 361;
    uint256 constant CRVUSD_WSTETH = 364;
    uint256 constant CRVUSD_LEVERAGE_WBTC = 344;
}
