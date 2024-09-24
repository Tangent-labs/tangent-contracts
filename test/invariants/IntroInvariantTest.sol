import "forge-std/Test.sol";
import "forge-std/console.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {LendSplitterHandler} from "./LendSplitterHandler.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";

import {Array} from "../../src/libs/Array.sol";

import "../../src/libs/Resources.sol";
import "../../src/libs/CvxConstantStructs.sol";
import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";

import {IgUSDSdt} from "../../src/interfaces/internals/IgUSDSdt.sol";
import {IgUSDCvx} from "../../src/interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../../src/interfaces/internals/IscvUSD.sol";
import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
import {ICommonStruct} from "../../src/interfaces/internals/ICommonStruct.sol";
contract IntroInvariantTest is Test {
    LendRewardSplitter private lendSplitter;
    LendSplitterHandler private lendSplitterHandler;
    LendRewardSplitterTestCommon private testCommon;

    address owner = makeAddr("owner");
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    CvxConstantStructs CVX_STRUCTS;

    function setUp() public {
        vm.createSelectFork("mainnet", 20725852);


        testCommon = new LendRewardSplitterTestCommon();

        vm.startPrank(owner);
        testCommon.deployProxyAdmin();
        testCommon.deployGUSDBeaconSdt();
        testCommon.deploySCVUSDBeaconSdt();
        testCommon.deployGUSDBeaconCvx();
        testCommon.deploySCVUSDBeaconCvx();
        lendSplitter = LendRewardSplitter(testCommon.deploySplitterProxy(owner));
        CVX_STRUCTS = new CvxConstantStructs(lendSplitter);


        // Retrieve all Vaults
        ILlamaLendVault[] memory allVaults = CVX_STRUCTS.getLlamaVaults();
        uint256[] memory pids = new uint256[](allVaults.length);

        // Iterates through all vaults to create the pid array
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaLendVault actualVault = allVaults[i];
            // Retrieve all the information needed to create the new cvx Market
            pids[i] = CVX_STRUCTS.getStruct(actualVault).pid;
        }

        // Market creation
        lendSplitter.createCvxMarkets(pids);

        // Iterates through all vaults to setup gUSD & scvUSD in their corresponding struct
        for (uint256 i; i < allVaults.length; i++) {
            ILlamaLendVault actualVault = allVaults[i];
            // Set the splitter token post market creation
            CVX_STRUCTS.setSplitterTokens(actualVault, lendSplitter.gUSDCvxPerLlamaVault(actualVault), lendSplitter.scvUSDCvxPerLlamaVault(actualVault));
        }

        lendSplitterHandler = new LendSplitterHandler(lendSplitter, CVX_STRUCTS);

        vm.stopPrank();

        (usr1);
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
        ILlamaLendVault[] memory allVaults = CVX_STRUCTS.getLlamaVaults();

        for (uint256 index = 0; index < allVaults.length; index++) {
            CvxConstantStructs.CvxStruct memory actualStruct = CVX_STRUCTS.getStruct(allVaults[index]);
            assertEq(lendSplitterHandler.sumsBalanceOfGUSD(actualStruct.llamaVault), actualStruct.gUSD.totalSupply());
            assertEq(lendSplitterHandler.sumsBalanceOfscvUSD(actualStruct.llamaVault), actualStruct.scvUSD.totalSupply());
        }
    }

    function afterInvariant() public {
        address[5] memory users = [usr1, usr2, usr3, usr4, usr5];
        for (uint256 userIndex; userIndex < users.length; userIndex++) {
            address user = users[userIndex];
            vm.startPrank(user);

            ILlamaLendVault[] memory allVaults = CVX_STRUCTS.getLlamaVaults();

            for (uint256 llamaVaultIndex = 0; llamaVaultIndex < allVaults.length; llamaVaultIndex++) {
                ILlamaLendVault actualVault = allVaults[llamaVaultIndex];
                CvxConstantStructs.CvxStruct memory actualStruct = CVX_STRUCTS.getStruct(allVaults[llamaVaultIndex]);

                uint256 gUSDBal = actualStruct.gUSD.balanceOf(user);
                uint256 scvUSDBal = actualStruct.scvUSD.balanceOf(user);

                actualStruct.scvUSD.processRewards();
                /// @dev Verify that users can withdraw their deposits
                if (gUSDBal != 0) {
                    lendSplitter.withdrawCvx(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, gUSDBal, false);
                }
                if (scvUSDBal != 0) {
                    lendSplitter.withdrawCvx(actualVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, scvUSDBal, true);
                }
                /// @dev Verify that users doesn't have splitter tokens anymore
                assertEq(actualStruct.gUSD.balanceOf(user), 0);
                assertEq(actualStruct.scvUSD.balanceOf(user), 0);
                console.log("yooo");
                /// @dev Assets all LP tokens & Reward tokens have removed from gUSD
                // assertEq(actualStruct.cvxRewardToken.balanceOf(address(actualStruct.gUSD)), 0);
                // assertEq(actualStruct.llamaVault.balanceOf(address(actualStruct.gUSD)), 0);

                /// @dev Verify that users can claim their rewards
                // console.log("coucou");
                // ICommonStruct.TokenAmount[] memory claimableGUSD = gUSD.claimableRewards(user);
                // for (uint256 index; index < claimableGUSD.length; index++) {
                //     if (claimableGUSD[index].amount != 0) {
                //         console.log("aaa");
                //         gUSD.getAndUpdateRewards(user);
                //         break;
                //     }
                // }
                // ICommonStruct.TokenAmount[] memory claimableSCVUSD = scvUSD.claimableRewards(user);
                // for (uint256 index; index < claimableSCVUSD.length; index++) {
                //     if (claimableSCVUSD[index].amount != 0) {
                //         console.log("yoooo");
                //         scvUSD.getAndUpdateRewards(user);
                //         break;
                //     }
                // }
            }

            vm.stopPrank();
        }
    }
}
