// // SPDX-License-Identifier: MIT
// import "../../../contexts/TestWrapper.sol";

// contract SociabilizationProcess is TestWrapper {
//     uint256 socFeePercentage;
//     uint256 socFeePending;

//     function setUp() public {
//         deployBaseContracts();
//         setUpSingleRandomMarket();
//         socFeePercentage = gUSD.socFeePercentage();
//         socFeePending = gUSD.socFeePending();
//     }

//     function test_process_sociabilizationProcess_callable_only_by_lendRewardSplitter(uint256 shareAmount) external {
//         address usr = makeAddr("Usr");
//         vm.startPrank(usr);
//         // PREPARE
//         vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, usr));
//         // ACTIONS
//         gUSD.sociabilizationProcess(shareAmount, true);
//     }

//     function test_process_sociabilizationProcess_with_stake_and_nothing_in_pending(uint256 shareAmount) external {
//         // PREPARE
//         vm.startPrank(address(splitter));

//         // ACTIONS
//         uint256 newShares = gUSD.sociabilizationProcess(shareAmount, true);

//         assertEq(newShares, shareAmount, "No socPendingFee so they should be same amounts");
//         assertEq(gUSD.socFeePending(), 0, "socFeePending should be equal to 0 as no fee are taken");
//     }

//     function test_process_sociabilizationProcess_with_no_stake(uint200 shareAmount) external {
//         // PREPARE
//         vm.startPrank(address(splitter));

//         uint256 feeTaken = (shareAmount * socFeePercentage) / gUSD.DENOMINATOR();

//         // ACTIONS
//         uint256 newShares = gUSD.sociabilizationProcess(shareAmount, false);

//         assertEq(newShares, shareAmount - feeTaken, "New shares should be equal to the inputShare minus the fees");
//         assertEq(gUSD.socFeePending(), feeTaken, "socFeePending should be equal to the fee taken");
//     }

//     function test_process_sociabilizationProcess_with_2_no_stake_then_stake(uint200 shareAmount1, uint200 shareAmount2, uint200 shareAmount3) external {
//         // PREPARE
//         vm.startPrank(address(splitter));

//         // ACTIONS 1
//         uint256 feeTaken1 = (shareAmount1 * socFeePercentage) / gUSD.DENOMINATOR();
//         uint256 newShares1 = gUSD.sociabilizationProcess(shareAmount1, false);

//         assertEq(newShares1, shareAmount1 - feeTaken1, "New shares should be equal to the inputShare minus the fees");
//         assertEq(gUSD.socFeePending(), feeTaken1, "socFeePending should be equal to feeTaken1");

//         // ACTIONS 2
//         uint256 feeTaken2 = (shareAmount2 * socFeePercentage) / gUSD.DENOMINATOR();

//         uint256 newShares2 = gUSD.sociabilizationProcess(shareAmount2, false);

//         assertEq(newShares2, shareAmount2 - feeTaken2, "New shares should be equal to the inputShare minus the fees");
//         assertEq(gUSD.socFeePending(), feeTaken1 + feeTaken2, "SocFeePending should be equal to the sum of both previous call");

//         // ACTIONS 3
//         uint256 newShares3 = gUSD.sociabilizationProcess(shareAmount3, true);

//         assertEq(newShares3, shareAmount3 + feeTaken1 + feeTaken2, "New shares should be equal to the inputShare minus the fees");
//         assertEq(gUSD.socFeePending(), 0, "SocFeePending should be equal to zero after staking at true");

//         // ACTIONS 4
//         uint256 newShares4 = gUSD.sociabilizationProcess(shareAmount1, false);

//         assertEq(newShares4, shareAmount1 - feeTaken1, "New shares should be equal to the inputShare minus the fees");
//         assertEq(gUSD.socFeePending(), feeTaken1, "SocFeePending should be equal to the sum of both previous call");
//     }
// }
