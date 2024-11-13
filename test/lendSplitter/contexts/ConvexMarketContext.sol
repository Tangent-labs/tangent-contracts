// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICvxRewardToken} from "../../../src/interfaces/externals/Convex/ICvxRewardToken.sol";
import {IStakeDaoVault} from "../../../src/interfaces/externals/StakeDao/IStakeDaoVault.sol";
import {ILlamaVault} from "../../../src/interfaces/externals/LlamaLend/ILlamaVault.sol";
import {ISdtLiquidityGauge} from "../../../src/interfaces/externals/StakeDao/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../../../src/interfaces/externals/Convex/ICvxBooster.sol";

import "../../../src/LendSplitter/LendRewardSplitter.sol";
import "../../../src/LendSplitter/tokens/gUSDCvx.sol";
import "../../../src/LendSplitter/tokens/scvUSDCvx.sol";

import "../../../src/LendSplitter/tokens/SplitterTokenComp.sol";

import "../../../src/libs/Resources/ResourcesGlobal.sol";
import "../../../src/libs/Resources/ResourcesYieldSplitter.sol";
import "../../../src/libs/Resources/ResourcesConvex.sol";

import "./DeployContext.sol";
import "./SpecialViews.sol";

import "../../utils/LowLevel.sol";
contract ConvexMarketContext is DeployContext, LowLevel, SpecialViews {
    ILlamaVault[] llamaVaultArray;
    mapping(ILlamaVault => CvxStruct) public structsMap;

    CvxStruct vaultStruct;
    ILlamaVault llamaVault;
    uint256 pid;
    IERC20 crvGauge;
    address crvAmm;
    ICvxRewardToken cvxRewardToken;
    IERC20 cvxVaultToken;
    IERC20 lendAsset;
    gUSDCvx gUSD;
    scvUSDCvx scvUSD;
    SplitterTokenComp scvUSDAutoCompound;
    ICrvUSDController crvController;

    struct CvxStruct {
        ILlamaVault llamaVault;
        uint256 pid;
        IERC20 crvGauge;
        ICrvUSDController crvController;
        address crvAmm;
        ICvxRewardToken cvxRewardToken;
        IERC20 cvxVaultToken;
        IERC20 lendAsset;
        gUSDCvx gUSD;
        scvUSDCvx scvUSD;
        SplitterTokenComp scvUSDAutoCompound;
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
            scvUSD: scvUSDCvx(address(0)),
            scvUSDAutoCompound: SplitterTokenComp(address(0))
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
            scvUSD: scvUSDCvx(address(0)),
            scvUSDAutoCompound: SplitterTokenComp(address(0))
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
            scvUSD: scvUSDCvx(address(0)),
            scvUSDAutoCompound: SplitterTokenComp(address(0))
        });
    }

    function setUpSingleRandomMarket() public {
        previewDeposits = new PreviewDeposits();
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
        scvUSDAutoCompound = vaultStruct.scvUSDAutoCompound;

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
        vm.label(address(scvUSDAutoCompound), string.concat("SCVUSD_AUTOCOMP_", collateralSymbol));
    }

    function createAndGetRandomMarket() public returns (CvxStruct memory) {
        previewDeposits = new PreviewDeposits();
        // console.log("Ici c'est la , ", previewDeposits.aa(), address(previewDeposits));
        // Pick a random vault and its related data
        CvxStruct memory cvxStruct = getStruct(pickRandomVault());

        // Create param for createMarket
        uint256[] memory pids = new uint256[](1);
        pids[0] = cvxStruct.pid;

        vm.recordLogs();
        vm.prank(owner);

        splitter.createMarkets(pids);

        // Retrieve the logs from createCvxMarket
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // The Event 'CreateCvxMarket' is the last of the transaction so we need to pick the last from the 'entries' list
        Vm.Log memory createLog = entries[entries.length - 1];

        (scvUSDCvx _scvUSD, SplitterTokenComp _scvUSDAutoCompound, gUSDCvx _gUSD) = abi.decode(createLog.data, (scvUSDCvx, SplitterTokenComp, gUSDCvx));
        cvxStruct.gUSD = _gUSD;
        cvxStruct.scvUSD = _scvUSD;
        cvxStruct.scvUSDAutoCompound = _scvUSDAutoCompound;
        return cvxStruct;
    }

    function pickRandomVault() public returns (ILlamaVault) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, llamaVaultArray.length - 1);
        return llamaVaultArray[randomIndex];
    }

    function dealLlamaVaultAsset(ILlamaVault _llamaVault, address user, uint256 shareAmount) public returns (uint256) {
        vm.startPrank(owner);
        uint256 assetAmount = _llamaVault.convertToAssets(shareAmount);
        IERC20 _lendAsset = IERC20(_llamaVault.borrowed_token());
        deal(address(_lendAsset), owner, assetAmount + 1000 ether);
        _lendAsset.approve(address(_llamaVault), UINT256_MAX);
        uint256 amountMinted = _llamaVault.mint(shareAmount, user);
        vm.stopPrank();
        return amountMinted;
    }

    function getAssetBeforeDeposit(ILlamaVault _llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE inType, address user, uint256 inAmount) public {
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            deal(lendAsset, user, inAmount);
            vm.prank(user);
            lendAsset.approve(address(splitter), MAX_UINT);
        } else {
            dealLlamaVaultAsset(llamaVault, user, inAmount);
            vm.prank(user);
            _llamaVault.approve(address(splitter), MAX_UINT);
        }
    }

    function getStruct(ILlamaVault _llamaVault) public view returns (CvxStruct memory) {
        return structsMap[_llamaVault];
    }

    function getLlamaVaults() public view returns (ILlamaVault[] memory) {
        return llamaVaultArray;
    }

    function setSplitterTokens(ILlamaVault _llamaVault, gUSDCvx _gUSD, scvUSDCvx _scvUSD) public {
        structsMap[_llamaVault].gUSD = _gUSD;
        structsMap[_llamaVault].scvUSD = _scvUSD;
    }

    function getShareAmountAfterSociabilization(uint256 sharesAmount, bool isStake) public view returns (uint256, uint256) {
        uint256 feeTakenOrGiven;
        if (isStake) {
            feeTakenOrGiven = gUSD.socFeePending();
            sharesAmount += feeTakenOrGiven;
        } else {
            feeTakenOrGiven = (sharesAmount * gUSD.socFeePercentage()) / gUSD.DENOMINATOR();
            sharesAmount -= feeTakenOrGiven;
        }
        return (sharesAmount, feeTakenOrGiven);
    }
}
