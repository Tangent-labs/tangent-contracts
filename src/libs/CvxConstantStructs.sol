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

import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";

import "./Resources.sol";

contract CvxConstantStructs is StdCheats, StdUtils, Test {
    LendRewardSplitter splitter;
    ILlamaLendVault[] llamaVaultArray;
    mapping(ILlamaLendVault => CvxStruct) public structsMap;

    struct CvxStruct {
        ILlamaLendVault llamaVault;
        uint256 pid;
        IERC20 crvGauge;
        address crvController;
        ICvxRewardToken cvxRewardToken;
        IERC20 cvxVaultToken;
        IERC20 lendAsset;
        IgUSDCvx gUSD;
        IscvUSD scvUSD;
    }

    constructor(LendRewardSplitter _splitter) {
        splitter = _splitter;
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_CRV);
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH);
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC);

        structsMap[AddrLlamaLendVaults.CRVUSD_CRV] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_CRV,
            pid: PidCvxBooster.CRVUSD_CRV,
            crvGauge: AddrCrvGauges.CRVUSD_CRV,
            crvController: AddrCrvController.CRVUSD_CRV,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_CRV,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_CRV,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: IgUSDCvx(address(0)),
            scvUSD: IscvUSD(address(0))
        });
        structsMap[AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH,
            pid: PidCvxBooster.CRVUSD_LEVERAGE_WETH,
            crvGauge: AddrCrvGauges.CRVUSD_LEVERAGE_WETH,
            crvController: AddrCrvController.CRVUSD_LEVERAGE_WETH,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_LEVERAGE_WETH,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_LEVERAGE_WETH,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: IgUSDCvx(address(0)),
            scvUSD: IscvUSD(address(0))
        });
        structsMap[AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC,
            pid: PidCvxBooster.CRVUSD_LEVERAGE_WBTC,
            crvGauge: AddrCrvGauges.CRVUSD_LEVERAGE_WBTC,
            crvController: AddrCrvController.CRVUSD_LEVERAGE_WBTC,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_LEVERAGE_WBTC,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_LEVERAGE_WBTC,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: IgUSDCvx(address(0)),
            scvUSD: IscvUSD(address(0))
        });
    }

    function createAndGetRandomMarket() public returns (CvxStruct memory) {
        CvxStruct memory cvxStruct = getStruct(pickRandomVault());
        uint256[] memory pids = new uint256[](1);
        pids[0] = cvxStruct.pid;
        vm.prank(splitter.owner());
        splitter.createCvxMarkets(pids);
        cvxStruct.gUSD = splitter.gUSDCvxPerLlamaVault(cvxStruct.llamaVault);
        cvxStruct.scvUSD = splitter.scvUSDCvxPerLlamaVault(cvxStruct.llamaVault);
        return cvxStruct;
    }

    function pickRandomVault() public returns (ILlamaLendVault) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, llamaVaultArray.length - 1);
        return llamaVaultArray[randomIndex];
    }

    function dealLlamaVaultAsset(ILlamaLendVault llamaVault, address user, uint256 shareAmount) public returns (uint256) {
        vm.startPrank(user);
        uint256 assetAmount = llamaVault.convertToAssets(shareAmount);
        deal(llamaVault.borrowed_token(), user, assetAmount + 1000 ether);
        IERC20(llamaVault.borrowed_token()).approve(address(llamaVault), UINT256_MAX);
        uint256 amountMinted = llamaVault.mint(shareAmount);
        vm.stopPrank();
        return amountMinted;
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
