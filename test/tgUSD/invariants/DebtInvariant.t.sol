import "../contexts/MarketDeploymentContext.sol";

import "../handler/Features/BorrowRepay/BorrowInvariantHandler.sol";

contract DebtInvariant is MarketDeploymentContext {
    address[] public users;

    MarketExternalActions[] public markets;

    BorrowInvariantHandler public borrowInvariantHandler;
    function setUp() public {
        markets.push(deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD));
        markets.push(deployConvexCurveLPMarket(AddrCurveStableLP.USDT_crvUSD));
        markets.push(deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD));

        MarketExternalActions[] memory marketsMemory = new MarketExternalActions[](markets.length);
        for (uint256 i; i < markets.length; i++) {
            marketsMemory[i] = markets[i];
        }

        users.push(usr1);
        users.push(usr2);
        users.push(usr3);
        users.push(usr4);
        users.push(usr5);
        users.push(usr6);

        targetSender(usr1);
        targetSender(usr2);
        targetSender(usr3);
        targetSender(usr4);
        targetSender(usr5);
        targetSender(usr6);

        borrowInvariantHandler = new BorrowInvariantHandler(marketsMemory, tgUSD);

        targetContract(address(borrowInvariantHandler));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MarketExternalActions.deposit.selector;
        selectors[1] = MarketExternalActions.borrow.selector;
        targetSelector(FuzzSelector({addr: address(borrowInvariantHandler), selectors: selectors}));
    }

    function pickRandomMarket() public returns (MarketExternalActions) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, markets.length - 1);
        return markets[randomIndex];
    }

    function invariant_debtSum_equals_totalDebt() public view {
        for (uint256 i; i < markets.length; i++) {
            uint256 debtSum;
            MarketExternalActions market = markets[i];
            for (uint256 j; j < users.length; j++) {
                debtSum += market.userDebt(users[j]);
            }
            assertApproxEqRel(debtSum, market.totalDebt(), 1e5, "Sum of all debts is not equal to the total debt of the market");
        }
    }

    function afterInvariant() public {
        for (uint256 i; i < markets.length; i++) {
            MarketExternalActions market = markets[i];
            for (uint256 j; j < users.length; j++) {}
            // assertEq(0, market.totalDebt(), "Total debt is equals to 0 after everything repayed");
        }
    }
}
