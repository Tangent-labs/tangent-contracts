// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICvxRewardToken} from "../interfaces/externals/ICvxRewardToken.sol";

import {IStakeDaoVault} from "../interfaces/externals/IStakeDaoVault.sol";
import {ILlamaLendVault} from "../interfaces/externals/ILlamaLendVault.sol";
import {ISdtLiquidityGauge} from "../interfaces/externals/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../interfaces/externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../interfaces/externals/ICvxRewardToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library AddrGlobal {
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address constant CRVUSD_CONTROLLER = 0xEdA215b7666936DEd834f76f3fBC6F323295110A;
    address constant CRVUSD_AMM = 0xafca625321Df8D6A068bDD8F1585d489D2acF11b;
}

library AddrClassicERC20 {
    // Tokens
    address constant TOKEN_CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address constant TOKEN_SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address constant TOKEN_CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address constant TOKEN_CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
}

library AddrSdtGauges {
    //Stake DAO crvUSD Gauges
    ISdtLiquidityGauge constant CRVUSD_CRV = ISdtLiquidityGauge(0xFCc5a1B4e3d80Ce459e346A0b8F63b655ED709cb);
    ISdtLiquidityGauge constant CRVUSD_LEVERAGE_WETH = ISdtLiquidityGauge(0x070365950CeCfC0b6a1A4e635638fe51495bA2F2);
}

library AddrLlamaLendVaults {
    // LlamaLend crvUSD Vaults (cvcrvUSD)
    ILlamaLendVault constant CRVUSD_CRV = ILlamaLendVault(0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA);
    ILlamaLendVault constant CRVUSD_LEVERAGE_WETH = ILlamaLendVault(0x8fb1c7AEDcbBc1222325C39dd5c1D2d23420CAe3);
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
    ICvxRewardToken constant CRVUSD_TBTC = ICvxRewardToken(0x57e94F41E596FC8315B20321156421c20CdC93f9);
    ICvxRewardToken constant CRVUSD_SUSDE = ICvxRewardToken(0xED2a17704bC5D5a7c5d256228333026B76A1732e);
    ICvxRewardToken constant CRVUSD_WETH = ICvxRewardToken(0xADde9073d897743E7004115Fa2452cC959FBF28a);
    ICvxRewardToken constant CRVUSD_WSTETH = ICvxRewardToken(0xbe3C3Fd181af6B99CC1bb9b0Ee065318aDFc4c96);
}

library AddrCvxVaultTokens {
    IERC20 constant CRVUSD_CRV = ICvxRewardToken(0xf0ac58AF1ca98aFce29fAe456E853688ab9d41E2);
}

library PidCvxBooster {
    //NORMAL
    uint256 constant CRVUSD_CRV = 325;
    uint256 constant CRVUSD_TBTC = 328;
    uint256 constant CRVUSD_SUSDE = 361;
    uint256 constant CRVUSD_WETH = 365;
    uint256 constant CRVUSD_WSTETH = 364;
}
