// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ConvexMarketContext.sol";

contract TestWrapper is ConvexMarketContext {
    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       DEPOSIT scvUSD
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function depositSCVUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isAutoCompound,
        bool isStake
    ) public returns (uint256 llamaVaultMinted, uint256 scvUSDReceived) {
        getAssetBeforeDeposit(llamaVault, inType, user, inAmount);
        (llamaVaultMinted, scvUSDReceived) = _prepareERC20TrackingDepositSCVUSD(inType, user, inAmount, isAutoCompound, isStake);

        vm.startPrank(user);
        scvUSDReceived = splitter.depositSCVUSD(llamaVault, inType, inAmount, isAutoCompound, isStake);
        vm.stopPrank();

        assertERC20Tracking();
    }

    function _prepareERC20TrackingDepositSCVUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isAutoCompound,
        bool isStake
    ) public returns (uint256 llamaVaultAmount, uint256 scvUSDExpected) {
        uint256 llamaVaultIn;
        uint256 llamaVaultMinted;
        uint256 socFeePending = gUSD.socFeePending();

        // Case deposit with the lend asset
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            llamaVaultAmount = llamaVault.convertToShares(inAmount);
            (scvUSDExpected, ) = getShareAmountAfterSociabilization(llamaVaultAmount, isStake);

            _verifyDepositWithLendAsset(user, inAmount, llamaVaultAmount);
        }
        // Case deposit with LlamaLendAsset
        else {
            llamaVaultAmount = inAmount;
            (scvUSDExpected, ) = getShareAmountAfterSociabilization(inAmount, isStake);
            _verifyDepositWithLlamaVaultAsset(user);
        }

        if (isStake) {
            _verifyStakingOnConvex(llamaVaultAmount);
        } else {
            _verifySociabilisation(llamaVaultAmount, scvUSDExpected);
        }

        if (isAutoCompound) {
            verifyReceiveERC20(scvUSD, address(scvUSDAutoCompound), scvUSDExpected);
            verifyBalERC20NotChanging(scvUSD, user);

            uint256 expectedAutoComp = scvUSDAutoCompound.convertToShares(scvUSDExpected);
            verifyMintERC20(scvUSDAutoCompound, expectedAutoComp);
            verifyReceiveERC20(scvUSDAutoCompound, user, expectedAutoComp);
        } else {
            verifyReceiveERC20(scvUSD, user, scvUSDExpected);

            verifySupplyERC20NotChanging(scvUSDAutoCompound);
            verifyBalERC20NotChanging(scvUSDAutoCompound, user);
        }

        verifySupplyERC20NotChanging(gUSD);
        verifyBalERC20NotChanging(gUSD, user);

        verifyMintERC20(scvUSD, scvUSDExpected);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       DEPOSIT GUSD
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
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

    function _prepareERC20TrackingDepositGUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isStake
    ) public returns (uint256 fee) {
        uint256 gUSDExpected;
        uint256 llamaVaultAmount;
        uint256 socFeePending = gUSD.socFeePending();

        // Case deposit with the lend asset
        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            (llamaVaultAmount, , fee, gUSDExpected) = previewDepositThenPreviewMint(llamaVault, lendAsset, gUSD, inAmount, isStake);

            _verifyDepositWithLendAsset(user, inAmount, llamaVaultAmount);
        }
        // Case deposit with LlamaLendAsset
        else {
            llamaVaultAmount = inAmount;
            uint256 sharesAmountAfterFees;
            (sharesAmountAfterFees, fee) = getShareAmountAfterSociabilization(llamaVaultAmount, isStake);
            gUSDExpected = llamaVault.convertToAssets(sharesAmountAfterFees);

            _verifyDepositWithLlamaVaultAsset(user);
        }

        if (isStake) {
            _verifyStakingOnConvex(llamaVaultAmount);
        } else {
            _verifySociabilisation(llamaVaultAmount, 0);
        }

        verifySupplyERC20NotChanging(scvUSD);
        verifyBalERC20NotChanging(scvUSD, user);

        verifyMintERC20(gUSD, gUSDExpected);
        verifyReceiveERC20(gUSD, user, gUSDExpected);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       WITHDRAW gUSD
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function withdrawGUSD(ILendRewardSplitter.CVX_TOKEN_TYPE outType, address user, uint256 outAmount) public {
        verifyBurnERC20(gUSD, outAmount);
        verifyLostERC20(gUSD, user, outAmount);

        verifySupplyERC20NotChanging(scvUSD);
        verifyBalERC20NotChanging(scvUSD, user);

        if (outType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            verifyReceiveERC20(lendAsset, user, llamaVault.convertToAssets(llamaVault.convertToShares(outAmount)));
        } else {
            verifyReceiveERC20(llamaVault, user, llamaVault.convertToShares(outAmount));
        }

        vm.prank(user);
        splitter.withdrawGUSD(llamaVault, outType, outAmount);

        assertERC20Tracking();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       WITHDRAW scvUSD
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function withdrawSCVUSD(ILendRewardSplitter.CVX_TOKEN_TYPE outType, address user, uint256 outAmount, bool isAutoCompound) public {
        uint256 burntSCVUSD = outAmount;
        if (isAutoCompound) {
            burntSCVUSD = scvUSDAutoCompound.convertToAssets(outAmount);

            verifyBurnERC20(scvUSDAutoCompound, outAmount);
            verifyLostERC20(scvUSDAutoCompound, user, outAmount);

            verifyBurnERC20(scvUSD, burntSCVUSD);
            verifyLostERC20(scvUSD, address(scvUSDAutoCompound), burntSCVUSD);
        } else {
            verifyBurnERC20(scvUSD, burntSCVUSD);
            verifyLostERC20(scvUSD, user, burntSCVUSD);

            verifySupplyERC20NotChanging(scvUSDAutoCompound);
            verifyBalERC20NotChanging(scvUSDAutoCompound, user);
        }

        verifySupplyERC20NotChanging(gUSD);
        verifyBalERC20NotChanging(gUSD, user);

        if (outType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            verifyReceiveERC20(lendAsset, user, llamaVault.convertToAssets(burntSCVUSD));

            // Verify that llamaVault LP is burnt
            verifyBurnERC20(llamaVault, burntSCVUSD);
            uint256 sharesAvailable = llamaVault.balanceOf(address(gUSD)) - gUSD.socFeePending();

            // If enough on gUSD to don't unstake anything from convex
            if (sharesAvailable >= burntSCVUSD) {
                verifyLostERC20(llamaVault, address(gUSD), burntSCVUSD);
            }
            // Else we need to unstake some llamaVault from the convex staking
            else {
                verifyLostERC20(llamaVault, address(crvGauge), burntSCVUSD);
            }
        } else {
            verifyReceiveERC20(llamaVault, user, burntSCVUSD);
        }

        vm.prank(user);
        splitter.withdrawSCVUSD(llamaVault, outType, outAmount, isAutoCompound);

        assertERC20Tracking();
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       ERC20 VERIFIES
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _verifyDepositWithLendAsset(address user, uint256 lendAssetAmount, uint256 llamaVaultMinted) internal {
        verifyLostERC20(lendAsset, user, lendAssetAmount);
        verifyReceiveERC20(lendAsset, address(crvController), lendAssetAmount);

        verifyMintERC20(llamaVault, llamaVaultMinted);
    }

    function _verifyDepositWithLlamaVaultAsset(address user) internal {
        verifyBalERC20NotChanging(lendAsset, user);
        verifyBalERC20NotChanging(lendAsset, address(crvController));

        verifySupplyERC20NotChanging(llamaVault);
    }

    function _verifyStakeAll() internal {
        uint256 llamaLpToStakeOnConvex = llamaVault.balanceOf(address(gUSD)) - gUSD.socFeePending();
        verifyLostERC20(llamaVault, address(gUSD), llamaLpToStakeOnConvex);
        verifyReceiveERC20(llamaVault, address(crvGauge), llamaLpToStakeOnConvex);

        verifyMintERC20(cvxRewardToken, llamaLpToStakeOnConvex);
        verifyReceiveERC20(cvxRewardToken, address(gUSD), llamaLpToStakeOnConvex);

        verifyMintERC20(crvGauge, llamaLpToStakeOnConvex);
        verifyReceiveERC20(crvGauge, address(AddrCvxGlobal.CVX_BOOSTER), llamaLpToStakeOnConvex);
    }

    function _verifyStakingOnConvex(uint256 llamaVaultAmount) internal {
        uint256 llamaLpToStakeOnConvex = llamaVault.balanceOf(address(gUSD)) + llamaVaultAmount;
        verifyLostERC20(llamaVault, address(gUSD), llamaVault.balanceOf(address(gUSD)));
        verifyReceiveERC20(llamaVault, address(crvGauge), llamaLpToStakeOnConvex);

        verifyMintERC20(cvxRewardToken, llamaLpToStakeOnConvex);
        verifyReceiveERC20(cvxRewardToken, address(gUSD), llamaLpToStakeOnConvex);

        verifyMintERC20(crvGauge, llamaLpToStakeOnConvex);
        verifyReceiveERC20(crvGauge, address(AddrCvxGlobal.CVX_BOOSTER), llamaLpToStakeOnConvex);
    }

    function _verifySociabilisation(uint256 llamaVaultIn, uint256 llamaVaultAfterFees) internal {
        verifyReceiveERC20(llamaVault, address(gUSD), llamaVaultIn);
        verifyBalERC20NotChanging(llamaVault, address(crvGauge));

        verifySupplyERC20NotChanging(cvxRewardToken);
        verifyBalERC20NotChanging(cvxRewardToken, address(gUSD));

        verifySupplyERC20NotChanging(crvGauge);
        verifyBalERC20NotChanging(crvGauge, address(AddrCvxGlobal.CVX_BOOSTER));
    }
}
