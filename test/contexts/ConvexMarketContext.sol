// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICvxRewardToken} from "../../src/interfaces/externals/ICvxRewardToken.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILlamaVault} from "../../src/interfaces/externals/ILlamaVault.sol";
import {ISdtLiquidityGauge} from "../../src/interfaces/externals/ISdtLiquidityGauge.sol";
import {ICvxBooster} from "../../src/interfaces/externals/ICvxBooster.sol";
import {ICvxRewardToken} from "../../src/interfaces/externals/ICvxRewardToken.sol";

import "../../src/LendRewardSplitter.sol";
import "../../src/tokens/gUSDCvx.sol";
import "../../src/tokens/scvUSDCvx.sol";

import "../../src/tokens/SplitterTokenComp.sol";

import "../../src/libs/Resources.sol";

import "./DeployContext.sol";
import "./SpecialViews.sol";
import "../utils/AssertERC20.sol";
import "../utils/LowLevel.sol";
contract ConvexMarketContext is DeployContext, AssertERC20, LowLevel, SpecialViews {
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

    function depositSCVUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isAutoCompound,
        bool isStake
    ) public returns (uint256) {
        getAssetBeforeDeposit(llamaVault, inType, user, inAmount);
        vm.startPrank(user);
        uint256 scvUSDReceived = splitter.depositSCVUSD(llamaVault, inType, inAmount, isAutoCompound, isStake);
        vm.stopPrank();
        return scvUSDReceived;
    }

    function _prepareERC20TrackingDepositGUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isStake
    ) public returns (uint256 fee) {
        uint256 gUSDExpected;
        uint256 lendAssetAmount;

        uint256 llamaVaultAmount;
        uint256 llamaVaultMinted;
        uint256 llamaVaultReceivedByGauge;
        uint256 llamaVaultReceivedByGUSD;

        uint256 socFeePending = gUSD.socFeePending();

        // Case deposit with the lend asset
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            lendAssetAmount = inAmount;
            (llamaVaultAmount, , fee, gUSDExpected) = previewDepositThenPreviewMint(llamaVault, lendAsset, gUSD, inAmount, isStake);
            llamaVaultMinted = llamaVaultAmount;

            verifyLostERC20(lendAsset, user, lendAssetAmount);
            verifyReceiveERC20(lendAsset, address(crvController), lendAssetAmount);
            verifyMintERC20(llamaVault, llamaVaultMinted);
        }
        // Case deposit with LlamaLendAsset
        else {
            llamaVaultAmount = inAmount;
            uint256 a;
            (a, fee) = getShareAmountAfterSociabilization(llamaVaultAmount, isStake);
            gUSDExpected = llamaVault.convertToAssets(a);

            verifyBalERC20NotChanging(lendAsset, user);
            verifyBalERC20NotChanging(lendAsset, address(crvController));

            verifySupplyERC20NotChanging(llamaVault);
        }

        // Case deposit with staking
        if (isStake) {
            llamaVaultReceivedByGauge = llamaVault.balanceOf(address(gUSD)) + llamaVaultAmount;
            socFeePending = 0;
            verifyLostERC20(llamaVault, address(gUSD), llamaVault.balanceOf(address(gUSD)));
            verifyReceiveERC20(llamaVault, address(crvGauge), llamaVaultReceivedByGauge);

            verifyMintERC20(cvxRewardToken, llamaVaultReceivedByGauge);
            verifyReceiveERC20(cvxRewardToken, address(gUSD), llamaVaultReceivedByGauge);

            verifyMintERC20(crvGauge, llamaVaultReceivedByGauge);
            verifyReceiveERC20(crvGauge, address(AddrGlobal.CVX_VOTER_PROXY), llamaVaultReceivedByGauge);
        }
        // Case deposit without staking
        else {
            llamaVaultReceivedByGUSD = llamaVaultAmount;
            socFeePending += fee;
            verifyReceiveERC20(llamaVault, address(gUSD), llamaVaultReceivedByGUSD);
            verifyBalERC20NotChanging(llamaVault, address(crvGauge));

            verifySupplyERC20NotChanging(cvxRewardToken);
            verifyBalERC20NotChanging(cvxRewardToken, address(gUSD));

            verifySupplyERC20NotChanging(crvGauge);
            verifyBalERC20NotChanging(crvGauge, address(AddrGlobal.CVX_VOTER_PROXY));
        }

        verifyMintERC20(gUSD, gUSDExpected);
        verifyReceiveERC20(gUSD, user, gUSDExpected);
    }

    function depositGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE inType, address user, uint256 inAmount, bool isStake) public returns (uint256) {
        getAssetBeforeDeposit(llamaVault, inType, user, inAmount);
        uint256 fee = _prepareERC20TrackingDepositGUSD(inType, user, inAmount, isStake);
        uint256 socFeePending;
        if (isStake) {
            socFeePending = 0;
        } else {
            socFeePending = gUSD.socFeePending() + fee;
        }

        vm.startPrank(user);
        uint256 gUSDReceived = splitter.depositGUSD(llamaVault, inType, inAmount, isStake);
        vm.stopPrank();

        assertEq(gUSD.socFeePending(), socFeePending, "Wrong socFeePending amount");
        assertERC20Tracking();
        return gUSDReceived;
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
