// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

/// @dev Reads the oracle from inside the ETH callback of the Curve pool (read-only reentrancy).
contract CvxEthReentrant {
    ICurveCryptoSwap public constant pool = AddrCryptoSwapLP.CVX_ETH_POOL;
    IPriceOracle public oracle;
    uint256 public priceInCallback;
    uint256 public lpPriceInCallback;
    uint256 public vpInCallback;

    constructor(IPriceOracle _oracle) {
        oracle = _oracle;
        AddrClassicERC20.CVX.approve(address(pool), type(uint256).max);
        IERC20(pool.coins(0)).approve(address(pool), type(uint256).max);
    }

    function removeBalanced(uint256 lp) external {
        pool.remove_liquidity(lp, [uint256(0), uint256(0)], true);
    }

    function removeOneCoinEth(uint256 lp) external {
        pool.remove_liquidity_one_coin(lp, 0, 0, true);
    }

    function sellCvxForEth(uint256 amount) external {
        pool.exchange(1, 0, amount, 0, true);
    }

    /// Factory crypto pools pull the input token through a callback to `sender`, mid-swap.
    function swapExtended(uint256 i, uint256 j, uint256 dx) external {
        (bool ok, bytes memory err) = address(pool).call(
            abi.encodeWithSignature(
                "exchange_extended(uint256,uint256,uint256,uint256,bool,address,address,bytes32)",
                i,
                j,
                dx,
                0,
                false,
                address(this),
                address(this),
                bytes32(this.curveCallback.selector)
            )
        );
        if (!ok) {
            assembly {
                revert(add(err, 32), mload(err))
            }
        }
    }

    function curveCallback(address, address, address coin, uint256 dx, uint256) external {
        require(msg.sender == address(pool));
        priceInCallback = oracle.latestAnswer(true);
        lpPriceInCallback = pool.lp_price();
        vpInCallback = pool.get_virtual_price();
        IERC20(coin).transfer(address(pool), dx);
    }

    receive() external payable {
        if (msg.sender != address(pool)) return;
        priceInCallback = oracle.latestAnswer(true);
        lpPriceInCallback = pool.lp_price();
        vpInCallback = pool.get_virtual_price();
    }
}

contract CvxEthOracleAttack is MarketDeploymentContext {
    ICurveCryptoSwap pool = AddrCryptoSwapLP.CVX_ETH_POOL;
    IERC20Metadata lp = AddrCryptoSwapLP.CVX_ETH_LP;
    IERC20Metadata weth = AddrClassicERC20.WETH;
    IERC20Metadata cvx = AddrClassicERC20.CVX;
    IPriceOracle oracle;
    CvxEthReentrant attacker;

    function setUp() external {
        deployStakeDaoVaultV2Market(lp);
        oracle = oracles[lp];
        attacker = new CvxEthReentrant(oracle);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    READ-ONLY REENTRANCY
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// Attacker owns `mult` x the pool, exits in ETH, reads the oracle mid-exit.
    /// get_virtual_price() is logged as a canary: it is the classic read-only reentrancy target.
    function test_reentrancy_remove_liquidity_balanced() external {
        _reentrancyAtScale(0, "remove_liquidity");
    }

    function test_reentrancy_remove_liquidity_one_coin_eth() external {
        _reentrancyAtScale(1, "remove_liquidity_one_coin");
    }

    function test_reentrancy_exchange_cvx_to_eth() external {
        _reentrancyAtScale(2, "exchange use_eth");
    }

    function _reentrancyAtScale(uint256 path, string memory label) internal {
        uint256[4] memory mults = [uint256(1), 10, 50, 200];
        for (uint256 k; k < mults.length; k++) {
            uint256 snap = vm.snapshotState();
            uint256 m = mults[k];
            // Curve newton_y reverts on swaps > ~10x the reserve, nothing to exploit there
            if (path == 2 && m > 10) break;

            if (path == 2) {
                deal(address(cvx), address(attacker), pool.balances(1) * m);
            } else {
                uint256 lpAmount = _mintLpWorth(pool.balances(0) * m, pool.balances(1) * m);
                vm.prank(usr1);
                lp.transfer(address(attacker), lpAmount);
            }
            uint256 before = oracle.latestAnswer(true);
            uint256 gvpBefore = pool.get_virtual_price();

            if (path == 0) attacker.removeBalanced(lp.balanceOf(address(attacker)));
            else if (path == 1) attacker.removeOneCoinEth(lp.balanceOf(address(attacker)) / 2);
            else attacker.sellCvxForEth(cvx.balanceOf(address(attacker)));

            console.log(label, "x pool size", m);
            _log("  oracle", before, attacker.priceInCallback());
            _log("  get_virtual_price (canary)", gvpBefore, attacker.vpInCallback());
            _assertCallbackPriceSafe(before);

            vm.revertToState(snap);
        }
    }

    /// Newer factory crypto pools pull tokens via a callback to `sender` (exchange_extended).
    /// This pool predates it: the selector hits the payable __default__ and is a silent no-op.
    function test_reentrancy_exchange_extended_not_available() external {
        uint256 dx = pool.balances(0);
        deal(address(weth), address(attacker), dx);
        uint256 bal0 = pool.balances(0);

        attacker.swapExtended(0, 1, dx);

        assertEq(attacker.priceInCallback(), 0, "callback reached");
        assertEq(pool.balances(0), bal0, "swap happened");
        assertEq(weth.balanceOf(address(attacker)), dx, "tokens moved");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    ATOMIC (FLASH LOAN) MANIPULATION
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function test_atomic_dump_cvx() external {
        uint256 before = oracle.latestAnswer(true);
        _swap(1, 0, pool.balances(1) * 5); // 5x the CVX reserve
        _log("atomic dump CVX", before, oracle.latestAnswer(true));
        assertGe(oracle.latestAnswer(true), before, "atomic swaps only add fees");
        assertApproxEqRel(oracle.latestAnswer(true), before, 0.015e18);
    }

    function test_atomic_dump_eth() external {
        uint256 before = oracle.latestAnswer(true);
        _swap(0, 1, pool.balances(0) * 5); // 5x the ETH reserve
        _log("atomic dump ETH", before, oracle.latestAnswer(true));
        assertGe(oracle.latestAnswer(true), before, "atomic swaps only add fees");
        assertApproxEqRel(oracle.latestAnswer(true), before, 0.015e18);
    }

    function test_atomic_imbalanced_add_remove() external {
        uint256 before = oracle.latestAnswer(true);
        uint256 lpAmount = _mintLpWorth(pool.balances(0) * 5, 0);
        _log("atomic add 5x ETH single-sided", before, oracle.latestAnswer(true));
        assertApproxEqRel(oracle.latestAnswer(true), before, 0.01e18);

        vm.prank(usr1);
        pool.remove_liquidity_one_coin(lpAmount, 1, 0); // exit in CVX
        _log("then remove in CVX", before, oracle.latestAnswer(true));
        assertApproxEqRel(oracle.latestAnswer(true), before, 0.01e18);
    }

    function test_donation_does_not_move_price() external {
        uint256 before = oracle.latestAnswer(true);
        deal(address(cvx), address(pool), cvx.balanceOf(address(pool)) * 10);
        deal(address(weth), address(pool), weth.balanceOf(address(pool)) * 10);
        vm.deal(address(pool), 1_000_000 ether);
        assertEq(oracle.latestAnswer(true), before, "donations must be ignored");
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    MULTI-BLOCK (EMA) MANIPULATION
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /// Attacker moves the spot price and holds it for N seconds (multi-block MEV / no arbitrage).
    /// Logs how far the EMA follows. Only the 1-block case is asserted, longer holds are reported.
    function test_ema_drift_pump_and_hold() external {
        _emaDrift(0, 1, "pump CVX (inflate collat)");
    }

    function test_ema_drift_dump_and_hold() external {
        _emaDrift(1, 0, "dump CVX (deflate collat -> liquidations)");
    }

    function _emaDrift(uint256 i, uint256 j, string memory label) internal {
        (, bytes memory ma) = address(pool).staticcall(abi.encodeWithSignature("ma_half_time()"));
        console.log(label);
        console.log("  ma_half_time", abi.decode(ma, (uint256)));
        console.log("  pool ETH", pool.balances(0) / 1e18, "pool CVX", pool.balances(1) / 1e18);

        uint256[7] memory holds = [uint256(12), 24, 36, 60, 300, 600, 3600];
        for (uint256 k; k < holds.length; k++) {
            uint256 snap = vm.snapshotState();
            uint256 before = oracle.latestAnswer(true);

            _swap(i, j, pool.balances(i)); // swap 1x the reserve of coin i
            skip(holds[k]);
            _swap(0, 1, 1 ether); // poke to write the EMA
            uint256 afterHold = oracle.latestAnswer(true);

            console.log("  hold (s)", holds[k]);
            _log("  ", before, afterHold);
            if (holds[k] <= 12) assertApproxEqRel(afterHold, before, 0.02e18, "one block of manipulation must stay < 2%");

            vm.revertToState(snap);
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            HELPERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _assertCallbackPriceSafe(uint256 before) internal view {
        assertGt(attacker.priceInCallback(), 0, "callback not reached");
        assertApproxEqRel(attacker.priceInCallback(), before, 0.01e18, "oracle moved inside Curve callback");
    }

    function _mintLpWorth(uint256 wethAmount, uint256 cvxAmount) internal returns (uint256) {
        vm.startPrank(usr1);
        deal(address(weth), usr1, wethAmount);
        deal(address(cvx), usr1, cvxAmount);
        weth.approve(address(pool), MAX_UINT);
        cvx.approve(address(pool), MAX_UINT);
        uint256 minted = pool.add_liquidity([wethAmount, cvxAmount], 0);
        vm.stopPrank();
        return minted;
    }

    function _swap(uint256 i, uint256 j, uint256 amount) internal {
        IERC20Metadata tokenIn = i == 0 ? weth : cvx;
        vm.startPrank(usr2);
        deal(address(tokenIn), usr2, amount);
        tokenIn.approve(address(pool), MAX_UINT);
        pool.exchange(i, j, amount, 0);
        vm.stopPrank();
    }

    function _log(string memory label, uint256 before, uint256 afterP) internal pure {
        int256 bps = (int256(afterP) - int256(before)) * 10_000 / int256(before);
        console.log(label);
        console.log("  before", before, "after", afterP);
        console.log("  delta bps");
        console.logInt(bps);
    }
}
