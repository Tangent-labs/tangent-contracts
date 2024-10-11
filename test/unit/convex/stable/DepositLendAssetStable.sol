// // SPDX-License-Identifier: UNKNOWN
// import "../../../contexts/ConvexMarketContext.sol";

// contract DepositLendAssetStable is ConvexMarketContext {
//     address usr = makeAddr("User");
//     function setUp() public {
//         deployBaseContracts();
//         setUpSingleRandomMarket();
//     }

//     function test_deposit_lend_asset_and_stake() external {
//         uint256 amountIn = 100 ether;
//         // PREPARE

//         deal(address(lendAsset), usr, amountIn);
//         vm.startPrank(usr);

//         uint256 sharesConverted = llamaVault.convertToShares(amountIn);

//         // FROM => TO

//         addERC20BalTracking(lendAsset, usr, amountIn, false);
//         addERC20BalTracking(lendAsset, address(crvController), amountIn, true);

//         addERC20SupplyTracking(scvUSD, sharesConverted, true);
//         addERC20BalTracking(scvUSD, usr, sharesConverted, true);

//         addERC20SupplyTracking(llamaVault, sharesConverted, true);
//         addERC20BalTracking(llamaVault, address(crvGauge), sharesConverted, true);
//         addERC20BalTracking(llamaVault, address(gUSD), 0, true);

//         addERC20SupplyTracking(cvxRewardToken, sharesConverted, true);
//         addERC20BalTracking(cvxRewardToken, address(gUSD), sharesConverted, true);

//         addERC20SupplyTracking(cvxRewardToken, sharesConverted, true);
//         addERC20BalTracking(cvxRewardToken, address(gUSD), sharesConverted, true);

//         addERC20BalTracking(gUSD, usr, 0, true);

//         // Balances changes check

//         // ACTIONS
//         lendAsset.approve(address(splitter), amountIn);
//         splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, true);

//         // VERIFY
//         assertERC20Tracking();
//         assertEq(gUSD.socFeePending(), 0, "Pending fee should not be incremented");
//     }

//     function test_deposit_lend_asset_and_no_stake() external {
//         uint256 amountIn = 200 ether;

//         // PREPARE
//         deal(address(lendAsset), usr, amountIn);
//         vm.startPrank(usr);

//         uint256 lendAssetAmountInShares = llamaVault.convertToShares(amountIn);

//         (uint256 sharesAfterFees, uint256 feeGiven) = getShareAmountAfterSociabilization(lendAssetAmountInShares, false);

//         addERC20BalTracking(lendAsset, usr, amountIn, false);
//         addERC20BalTracking(lendAsset, address(crvController), amountIn, true);

//         addERC20SupplyTracking(scvUSD, sharesAfterFees, true);
//         addERC20BalTracking(scvUSD, usr, sharesAfterFees, true);

//         addERC20SupplyTracking(llamaVault, lendAssetAmountInShares, true);
//         addERC20BalTracking(llamaVault, address(gUSD), lendAssetAmountInShares, true);

//         addERC20BalTracking(gUSD, usr, 0, true);
//         addERC20BalTracking(llamaVault, address(crvGauge), 0, true);
//         addERC20BalTracking(cvxRewardToken, address(gUSD), 0, true);
//         addERC20BalTracking(crvGauge, AddrGlobal.CVX_VOTER_PROXY, 0, true);

//         // ACTIONS
//         lendAsset.approve(address(splitter), amountIn);
//         splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, false);

//         // VERIFY
//         assertERC20Tracking();
//         assertEq(gUSD.socFeePending(), feeGiven, "Wrong amount of pending fees incremented");
//     }

//     function test_deposit_lend_asset_with_no_stake_then_deposit_with_stake() external {
//         uint256 amountIn = 200 ether;

//         deal(address(lendAsset), usr, amountIn * 2);
//         vm.startPrank(usr);

//         // PREPARE

//         uint256 lendAssetAmountInShares1 = llamaVault.convertToShares(amountIn);
//         (uint256 sharesAfterFees, uint256 feeGiven) = getShareAmountAfterSociabilization(lendAssetAmountInShares1, false);

//         addERC20BalTracking(lendAsset, usr, amountIn, false);
//         addERC20BalTracking(lendAsset, address(crvController), amountIn, true);

//         addERC20SupplyTracking(scvUSD, sharesAfterFees, true);
//         addERC20BalTracking(scvUSD, usr, sharesAfterFees, true);

//         addERC20SupplyTracking(llamaVault, lendAssetAmountInShares1, true);
//         addERC20BalTracking(llamaVault, address(gUSD), lendAssetAmountInShares1, true);

//         addERC20BalTracking(gUSD, usr, 0, true);
//         addERC20BalTracking(llamaVault, address(crvGauge), 0, true);
//         addERC20BalTracking(cvxRewardToken, address(gUSD), 0, true);
//         addERC20BalTracking(crvGauge, AddrGlobal.CVX_VOTER_PROXY, 0, true);

//         // ACTIONS
//         lendAsset.approve(address(splitter), amountIn * 2);
//         splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, false);

//         // VERIFY
//         assertERC20Tracking();
//         assertEq(gUSD.socFeePending(), feeGiven);

//         // PREPARE
//         uint256 lendAssetAmountInShares2 = llamaVault.convertToShares(amountIn);

//         uint256 sharesToStake = lendAssetAmountInShares1 + lendAssetAmountInShares2;

//         uint256 scvUSDToMint = lendAssetAmountInShares2 + feeGiven;

//         addERC20BalTracking(lendAsset, usr, amountIn, false);
//         addERC20BalTracking(lendAsset, address(crvController), amountIn, true);

//         addERC20SupplyTracking(scvUSD, scvUSDToMint, true);
//         addERC20BalTracking(scvUSD, usr, scvUSDToMint, true);

//         addERC20SupplyTracking(llamaVault, lendAssetAmountInShares2, true);
//         addERC20BalTracking(llamaVault, address(gUSD), lendAssetAmountInShares1, false);
//         addERC20BalTracking(llamaVault, address(crvGauge), sharesToStake, true);

//         addERC20SupplyTracking(cvxRewardToken, sharesToStake, true);
//         addERC20BalTracking(cvxRewardToken, address(gUSD), sharesToStake, true);

//         addERC20SupplyTracking(crvGauge, sharesToStake, true);
//         addERC20BalTracking(crvGauge, AddrGlobal.CVX_VOTER_PROXY, sharesToStake, true);

//         addERC20BalTracking(gUSD, usr, 0, true);

//         // ACTIONS

//         splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, amountIn, false, true);

//         // VERIFY
//         assertERC20Tracking();
//         assertEq(gUSD.socFeePending(), 0, "Wrong amount of pending fees incremented");
//     }
// }
