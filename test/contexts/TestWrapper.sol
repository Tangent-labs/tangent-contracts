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

        vm.prank(user);
        uint256 scvUSDReceived = splitter.depositSCVUSD(llamaVault, inType, inAmount, isAutoCompound, isStake);

        assertERC20Tracking();
    }

    function _prepareERC20TrackingDepositSCVUSD(
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        address user,
        uint256 inAmount,
        bool isAutoCompound,
        bool isStake
    ) public returns (uint256 llamaVaultAmount, uint256 scvUSDExpected) {
        uint256 scvUSDExpected;
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
        verifySupplyERC20NotChanging(gUSD);
        verifyBalERC20NotChanging(gUSD, user);

        verifyMintERC20(scvUSD, scvUSDExpected);
        verifyReceiveERC20(scvUSD, user, scvUSDExpected);
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
        verifyReceiveERC20(crvGauge, address(AddrGlobal.CVX_VOTER_PROXY), llamaLpToStakeOnConvex);
    }

    function _verifyStakingOnConvex(uint256 llamaVaultAmount) internal {
        uint256 llamaLpToStakeOnConvex = llamaVault.balanceOf(address(gUSD)) + llamaVaultAmount;
        verifyLostERC20(llamaVault, address(gUSD), llamaVault.balanceOf(address(gUSD)));
        verifyReceiveERC20(llamaVault, address(crvGauge), llamaLpToStakeOnConvex);

        verifyMintERC20(cvxRewardToken, llamaLpToStakeOnConvex);
        verifyReceiveERC20(cvxRewardToken, address(gUSD), llamaLpToStakeOnConvex);

        verifyMintERC20(crvGauge, llamaLpToStakeOnConvex);
        verifyReceiveERC20(crvGauge, address(AddrGlobal.CVX_VOTER_PROXY), llamaLpToStakeOnConvex);
    }

    function _verifySociabilisation(uint256 llamaVaultIn, uint256 llamaVaultAfterFees) internal {
        console.log(llamaVaultIn, llamaVaultAfterFees);
        verifyReceiveERC20(llamaVault, address(gUSD), llamaVaultIn);
        verifyBalERC20NotChanging(llamaVault, address(crvGauge));

        verifySupplyERC20NotChanging(cvxRewardToken);
        verifyBalERC20NotChanging(cvxRewardToken, address(gUSD));

        verifySupplyERC20NotChanging(crvGauge);
        verifyBalERC20NotChanging(crvGauge, address(AddrGlobal.CVX_VOTER_PROXY));
    }
}
