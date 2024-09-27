// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console.sol";
import "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {ICvxRewardToken} from "../../src/interfaces/externals/ICvxRewardToken.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
import {ISdtLiquidityGauge} from "../../src/interfaces/externals/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../../src/interfaces/externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../../src/interfaces/externals/ICvxRewardToken.sol";

import "../../src/LendRewardSplitter.sol";
import "../../src/tokens/convex/gUSDCvx.sol";
import "../../src/tokens/convex/scvUSDCvx.sol";

import "../../src/libs/Resources.sol";

import "../DeployContext.sol";

contract ConvexMarketContext is StdCheats, StdUtils, DeployContext {
    ILlamaLendVault[] llamaVaultArray;
    mapping(ILlamaLendVault => CvxStruct) public structsMap;

    CvxStruct vaultStruct;
    ILlamaLendVault llamaVault;
    uint256 pid;
    IERC20 crvGauge;
    address crvAmm;
    ICvxRewardToken cvxRewardToken;
    IERC20 cvxVaultToken;
    IERC20 lendAsset;
    gUSDCvx gUSD;
    scvUSDCvx scvUSD;
    ICrvUSDController crvController;

    struct CvxStruct {
        ILlamaLendVault llamaVault;
        uint256 pid;
        IERC20 crvGauge;
        ICrvUSDController crvController;
        address crvAmm;
        ICvxRewardToken cvxRewardToken;
        IERC20 cvxVaultToken;
        IERC20 lendAsset;
        gUSDCvx gUSD;
        scvUSDCvx scvUSD;
    }

    constructor() {
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_CRV);
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH);
        llamaVaultArray.push(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC);

        structsMap[AddrLlamaLendVaults.CRVUSD_CRV] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_CRV,
            pid: PidCvxBooster.CRVUSD_CRV,
            crvGauge: AddrCrvGauges.CRVUSD_CRV,
            crvController: AddrCrvController.CRVUSD_CRV,
            crvAmm: AddrCrvAmm.CRVUSD_CRV,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_CRV,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_CRV,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: gUSDCvx(address(0)),
            scvUSD: scvUSDCvx(address(0))
        });
        structsMap[AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH,
            pid: PidCvxBooster.CRVUSD_LEVERAGE_WETH,
            crvGauge: AddrCrvGauges.CRVUSD_LEVERAGE_WETH,
            crvController: AddrCrvController.CRVUSD_LEVERAGE_WETH,
            crvAmm: AddrCrvAmm.CRVUSD_LEVERAGE_WETH,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_LEVERAGE_WETH,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_LEVERAGE_WETH,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: gUSDCvx(address(0)),
            scvUSD: scvUSDCvx(address(0))
        });
        structsMap[AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC] = CvxStruct({
            llamaVault: AddrLlamaLendVaults.CRVUSD_LEVERAGE_WBTC,
            pid: PidCvxBooster.CRVUSD_LEVERAGE_WBTC,
            crvGauge: AddrCrvGauges.CRVUSD_LEVERAGE_WBTC,
            crvController: AddrCrvController.CRVUSD_LEVERAGE_WBTC,
            crvAmm: AddrCrvAmm.CRVUSD_LEVERAGE_WBTC,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_LEVERAGE_WBTC,
            cvxVaultToken: AddrCvxVaultTokens.CRVUSD_LEVERAGE_WBTC,
            lendAsset: AddrClassicERC20.TOKEN_CRVUSD,
            gUSD: gUSDCvx(address(0)),
            scvUSD: scvUSDCvx(address(0))
        });
    }

    function setUpSingleRandomMarket() public {
        vaultStruct = createAndGetRandomMarket();

        llamaVault = vaultStruct.llamaVault;
        pid = vaultStruct.pid;
        crvGauge = vaultStruct.crvGauge;
        crvController = vaultStruct.crvController;
        crvAmm = vaultStruct.crvAmm;
        cvxRewardToken = vaultStruct.cvxRewardToken;
        cvxVaultToken = vaultStruct.cvxVaultToken;
        lendAsset = vaultStruct.lendAsset;
        gUSD = vaultStruct.gUSD;
        scvUSD = vaultStruct.scvUSD;

        string memory collateralSymbol = IERC20Metadata(llamaVault.collateral_token()).symbol();

        vm.label(address(llamaVault), string.concat("LLAMA_VAULT_", collateralSymbol));
        vm.label(address(crvGauge), string.concat("CRV_GAUGE_", collateralSymbol));
        vm.label(address(crvController), string.concat("CRV_CONTROLLER_", collateralSymbol));
        vm.label(address(crvAmm), string.concat("CRV_AMM_", collateralSymbol));
        vm.label(address(cvxRewardToken), string.concat("CVX_REWARD_TOKEN_", collateralSymbol));
        vm.label(address(cvxVaultToken), string.concat("CVX_VAULT_TOKEN_", collateralSymbol));
        vm.label(address(lendAsset), "CRVUSD");
        vm.label(address(gUSD), string.concat("GUSD_", collateralSymbol));
        vm.label(address(scvUSD), string.concat("SCVUSD_", collateralSymbol));
    }

    function createAndGetRandomMarket() public returns (CvxStruct memory) {
        CvxStruct memory cvxStruct = getStruct(pickRandomVault());
        uint256[] memory pids = new uint256[](1);
        pids[0] = cvxStruct.pid;
        vm.prank(owner);
        splitter.createCvxMarkets(pids);
        cvxStruct.gUSD = gUSDCvx(address(splitter.gUSDCvxPerLlamaVault(cvxStruct.llamaVault)));
        cvxStruct.scvUSD = scvUSDCvx(address(splitter.scvUSDCvxPerLlamaVault(cvxStruct.llamaVault)));
        return cvxStruct;
    }

    function pickRandomVault() public returns (ILlamaLendVault) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, llamaVaultArray.length - 1);
        return llamaVaultArray[randomIndex];
    }

    function dealLlamaVaultAsset(ILlamaLendVault _llamaVault, address user, uint256 shareAmount) public returns (uint256) {
        vm.startPrank(user);
        uint256 assetAmount = _llamaVault.convertToAssets(shareAmount);
        deal(_llamaVault.borrowed_token(), user, assetAmount + 1000 ether);
        IERC20(_llamaVault.borrowed_token()).approve(address(_llamaVault), UINT256_MAX);
        uint256 amountMinted = _llamaVault.mint(shareAmount);
        vm.stopPrank();
        return amountMinted;
    }

    function getStruct(ILlamaLendVault _llamaVault) public view returns (CvxStruct memory) {
        return structsMap[_llamaVault];
    }

    function getLlamaVaults() public view returns (ILlamaLendVault[] memory) {
        return llamaVaultArray;
    }

    function setSplitterTokens(ILlamaLendVault _llamaVault, gUSDCvx _gUSD, scvUSDCvx _scvUSD) public {
        structsMap[_llamaVault].gUSD = _gUSD;
        structsMap[_llamaVault].scvUSD = _scvUSD;
    }
}
