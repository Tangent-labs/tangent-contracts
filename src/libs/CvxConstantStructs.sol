// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {ICvxRewardToken} from "../interfaces/externals/ICvxRewardToken.sol";

import {IStakeDaoVault} from "../interfaces/externals/IStakeDaoVault.sol";
import {ILlamaLendVault} from "../interfaces/externals/ILlamaLendVault.sol";
import {ISdtLiquidityGauge} from "../interfaces/externals/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../interfaces/externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../interfaces/externals/ICvxRewardToken.sol";
import {IgUSDCvx} from "../interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../interfaces/internals/IscvUSD.sol";
import "./Resources.sol";

contract CvxConstantStructs is StdCheats, StdUtils, Test {
    ILlamaLendVault[] llamaVaultArray;
    mapping(ILlamaLendVault => CvxStruct) public structsMap;

    struct CvxStruct {
        ILlamaLendVault llamaVault;
        uint256 pid;
        ICvxRewardToken cvxRewardToken;
        IERC20 cvxVaultToken;
        IERC20 lendAsset;
        IgUSDCvx gUSD;
        IscvUSD scvUSD;
    }

    constructor() {
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_CRV);
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH);

        structsMap[AddrLlamaLendVaults.CRVUSD_CRV] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_CRV,
            pid: PidCvxBooster.CRVUSD_CRV,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_CRV,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_CRV,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: IgUSDCvx(address(0)),
            scvUSD: IscvUSD(address(0))
        });
        structsMap[AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH,
            pid: PidCvxBooster.CRVUSD_LEVERAGE_WETH,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_LEVERAGE_WETH,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_LEVERAGE_WETH,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: IgUSDCvx(address(0)),
            scvUSD: IscvUSD(address(0))
        });
    }

    function pickRandomVault() public returns (ILlamaLendVault) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, llamaVaultArray.length - 1);
        return llamaVaultArray[randomIndex];
    }

    function getStruct(ILlamaLendVault llamaVault) public view returns (CvxStruct memory) {
        return structsMap[llamaVault];
    }
    function getLlamaVaults() public view returns (ILlamaLendVault[] memory) {
        return llamaVaultArray;
    }

    function setSplitterTokens(ILlamaLendVault llamaVault, IgUSDCvx gUSD, IscvUSD scvUSD) public {
        structsMap[llamaVault].gUSD = gUSD;
        structsMap[llamaVault].scvUSD = scvUSD;
    }
}
