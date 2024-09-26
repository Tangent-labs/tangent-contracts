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
        ILlamaLendVault[] memory allVaults = getLlamaVaults();
        uint256[] memory pids = new uint256[](allVaults.length);

        // Iterates through all vaults to create the pid array
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaLendVault actualVault = allVaults[i];
            // Retrieve all the information needed to create the new cvx Market
            pids[i] = structsMap[actualVault].pid;
        }
        vm.startPrank(owner);
        // Market creation
        splitter.createCvxMarkets(pids);

        // Iterates through all vaults to setup gUSD & scvUSD in their corresponding struct
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaLendVault actualVault = allVaults[i];
            // Set the splitter token post market creation
            setSplitterTokens(
                actualVault,
                gUSDCvx(address(splitter.gUSDCvxPerLlamaVault(actualVault))),
                scvUSDCvx(address(splitter.scvUSDCvxPerLlamaVault(actualVault)))
            );
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
            ILlamaLendVault actualVault = llamaVaultArray[llamaVaultIndex];
            CvxStruct memory actualStruct = structsMap[llamaVaultArray[llamaVaultIndex]];

            try actualStruct.scvUSD.processRewards() {} catch {}
            try actualStruct.gUSD.processRewards() {} catch {}
            // Let the rewards stream fully
            skip(7 days);
            for (uint256 userIndex; userIndex < users.length; userIndex++) {
                address user = users[userIndex];
                vm.startPrank(user);

                /// @dev Verify that users can claim their rewards
                ICommonStruct.TokenAmount[] memory claimableGUSD = actualStruct.gUSD.claimableRewards(user);
                for (uint256 index; index < claimableGUSD.length; index++) {
                    if (claimableGUSD[index].amount != 0) {
                        splitter.claimSimple(address(actualStruct.gUSD), user);
                        break;
                    }
                }
                ICommonStruct.TokenAmount[] memory claimableSCVUSD = actualStruct.scvUSD.claimableRewards(user);
                for (uint256 index; index < claimableSCVUSD.length; index++) {
                    if (claimableSCVUSD[index].amount != 0) {
                        splitter.claimSimple(address(actualStruct.scvUSD), user);
                        break;
                    }
                }

                uint256 gUSDBal = actualStruct.gUSD.balanceOf(user);
                uint256 scvUSDBal = actualStruct.scvUSD.balanceOf(user);
                /// @dev Verify that users can withdraw their deposits
                if (gUSDBal != 0) {
                    splitter.withdrawCvx(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSDBal, false);
                }
                if (scvUSDBal != 0) {
                    splitter.withdrawCvx(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSDBal, true);
                }

                /// @dev Verify that users doesn't have splitter tokens anymore
                assertEq(actualStruct.gUSD.balanceOf(user), 0, "gUSD balance of user is empty");
                assertEq(actualStruct.scvUSD.balanceOf(user), 0, "scvUSD balance of user is empty");
                vm.stopPrank();
            }
            assertEq(actualStruct.gUSD.totalSupply(), 0);
            assertEq(actualStruct.scvUSD.totalSupply(), 0);

            // @dev Assets all LP tokens & Reward tokens have removed from gUSD
            assertEq(
                actualStruct.cvxRewardToken.balanceOf(address(actualStruct.gUSD)) + actualStruct.llamaVault.balanceOf(address(actualStruct.gUSD)),
                actualStruct.scvUSD.getStreamableShares()
            );
        }
    }
}
