import "../LendingContext.sol";
import "../convex/ConvexMarketContext.sol";
import "./LendSplitterHandler.sol";
contract GlobalInvariant is ConvexMarketContext {
    LendSplitterHandler private lendSplitterHandler;

    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    function setUp() public {
        deployBaseContracts();

        // Retrieve all Vaults
        ILlamaVault[] memory allVaults = getLlamaVaults();
        uint256[] memory pids = new uint256[](allVaults.length);

        // Iterates through all vaults to create the pid array
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaVault actualVault = allVaults[i];
            // Retrieve all the information needed to create the new cvx Market
            pids[i] = structsMap[actualVault].pid;
        }
        vm.startPrank(owner);
        // Market creation
        splitter.createMarkets(pids);

        // Iterates through all vaults to setup gUSD & scvUSD in their corresponding struct
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaVault actualVault = allVaults[i];
            // Set the splitter token post market creation
            setSplitterTokens(
                actualVault,
                gUSDCvx(address(splitter.gUSDPerLlamaVault(actualVault))),
                scvUSDCvx(address(splitter.scvUSDPerLlamaVault(actualVault)))
            );
            string memory collateralSymbol = IERC20Metadata(actualVault.collateral_token()).symbol();

            vm.label(address(actualVault), string.concat("LLAMA_VAULT_", collateralSymbol));
            vm.label(address(structsMap[actualVault].crvGauge), string.concat("CRV_GAUGE_", collateralSymbol));
            vm.label(address(structsMap[actualVault].crvController), string.concat("CRV_CONTROLLER_", collateralSymbol));
            vm.label(address(structsMap[actualVault].crvAmm), string.concat("CRV_AMM_", collateralSymbol));
            vm.label(address(structsMap[actualVault].cvxRewardToken), string.concat("CVX_REWARD_TOKEN_", collateralSymbol));
            vm.label(address(structsMap[actualVault].cvxVaultToken), string.concat("CVX_VAULT_TOKEN_", collateralSymbol));
            vm.label(address(structsMap[actualVault].gUSD), string.concat("GUSD_", collateralSymbol));
            vm.label(address(structsMap[actualVault].scvUSD), string.concat("SCVUSD_", collateralSymbol));
        }

        lendSplitterHandler = new LendSplitterHandler(splitter, ConvexMarketContext(address(this)));

        vm.stopPrank();

        targetSender(usr1);
        targetSender(usr2);
        targetSender(usr3);
        targetSender(usr4);
        targetSender(usr5);
        targetSender(usr6);

        targetContract(address(lendSplitterHandler));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = LendSplitterHandler.depositCvx.selector;
        selectors[1] = LendSplitterHandler.withdrawCvx.selector;
        targetSelector(FuzzSelector({addr: address(lendSplitterHandler), selectors: selectors}));
    }

    function invariant_sumBalances_equals_totalSupply() public view {
        for (uint256 index = 0; index < llamaVaultArray.length; index++) {
            CvxStruct memory actualStruct = structsMap[llamaVaultArray[index]];
            assertEq(lendSplitterHandler.sumsBalanceOfGUSD(actualStruct.llamaVault), actualStruct.gUSD.totalSupply());
            assertEq(lendSplitterHandler.sumsBalanceOfscvUSD(actualStruct.llamaVault), actualStruct.scvUSD.totalSupply());
        }
    }

    function afterInvariant() public {
        address[6] memory users = [usr1, usr2, usr3, usr4, usr5, usr6];

        for (uint256 llamaVaultIndex = 0; llamaVaultIndex < llamaVaultArray.length; llamaVaultIndex++) {
            uint256 totalScvNotWithdrawable;
            uint256 totalGUsdNotWithdrawable;
            ILlamaVault actualVault = llamaVaultArray[llamaVaultIndex];
            CvxStruct memory actualStruct = structsMap[llamaVaultArray[llamaVaultIndex]];

            try actualStruct.gUSD.processGovRewards() {} catch {}
            try actualStruct.gUSD.processStableRewards() {} catch {}
            // Let the rewards stream fully
            skip(7 days);
            for (uint256 userIndex; userIndex < users.length; userIndex++) {
                address user = users[userIndex];
                vm.startPrank(user);

                /// @dev Verify that users can claim their rewards
                ICommonStruct.TokenAmount[] memory claimableGUSD = actualStruct.gUSD.claimableRewards(user);
                for (uint256 index; index < claimableGUSD.length; index++) {
                    if (claimableGUSD[index].amount != 0) {
                        splitter.claimSimple(address(actualStruct.gUSD));
                        break;
                    }
                }
                ICommonStruct.TokenAmount[] memory claimableSCVUSD = actualStruct.scvUSD.claimableRewards(user);
                for (uint256 index; index < claimableSCVUSD.length; index++) {
                    if (claimableSCVUSD[index].amount != 0) {
                        splitter.claimSimple(address(actualStruct.scvUSD));
                        break;
                    }
                }

                uint256 gUSDBal = actualStruct.gUSD.balanceOf(user);
                uint256 scvUSDBal = actualStruct.scvUSD.balanceOf(user);
                uint256 amountLendAssetInController = actualStruct.lendAsset.balanceOf(address(actualStruct.crvController));
                uint256 gUSDNotWithdrawable;
                uint256 scvNotWithdrawable;
                /// @dev Verify that users can withdraw their deposits
                if (gUSDBal != 0) {
                    // In case utilisation rate is too high
                    if (gUSDBal > amountLendAssetInController) {
                        gUSDNotWithdrawable = gUSDBal - amountLendAssetInController;
                        totalGUsdNotWithdrawable += gUSDNotWithdrawable;
                        gUSDBal = amountLendAssetInController;
                    }
                    if (gUSDBal != 0) {
                        splitter.withdrawGUSD(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSDBal);
                    }
                }
                amountLendAssetInController = actualStruct.lendAsset.balanceOf(address(actualStruct.crvController));

                if (scvUSDBal != 0) {
                    // In case utilisation rate is too high

                    if (actualVault.convertToAssets(scvUSDBal) > amountLendAssetInController) {
                        scvNotWithdrawable = scvUSDBal - actualVault.convertToShares(amountLendAssetInController);
                        totalScvNotWithdrawable += scvNotWithdrawable;
                        scvUSDBal = actualVault.convertToShares(amountLendAssetInController);
                    }
                    if (scvUSDBal != 0) {
                        splitter.withdrawSCVUSD(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSDBal, false);
                    }
                }
                amountLendAssetInController = actualStruct.lendAsset.balanceOf(address(actualStruct.crvController));

                // Equals to what is not withdrawable
                assertEq(actualStruct.gUSD.balanceOf(user), gUSDNotWithdrawable, "gUSD balance of the user is equal to 0 or what he couldn't withdraw");
                assertEq(actualStruct.scvUSD.balanceOf(user), scvNotWithdrawable, "scvUSD balance of the user is equal to 0 or what he couldn't withdraw");

                vm.stopPrank();
            }

            assertEq(actualStruct.gUSD.totalSupply(), totalGUsdNotWithdrawable, "gUSD totalSupply is equal to 0 or what couldn't be withrawn");
            assertEq(actualStruct.scvUSD.totalSupply(), totalScvNotWithdrawable, "scvUSD totalSupply is equal to 0 or what couldn't be withrawn");
        }
    }
}
