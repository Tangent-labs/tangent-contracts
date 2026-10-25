// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// Reward token that can block transfers to an address (USDC/USDT blacklist, or pause)
contract BlockableToken is ERC20 {
    mapping(address => bool) public blocked;

    constructor() ERC20("Blk", "BLK") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }

    function setBlocked(address a, bool b) external {
        blocked[a] = b;
    }

    function _update(address from, address to, uint256 v) internal override {
        require(!blocked[to] && !blocked[from], "blocked");
        super._update(from, to, v);
    }
}

contract VsTanAuditPoC is MarketDeploymentContext {
    function _lock(address usr, uint208 amount, bool perma) internal returns (uint256 id) {
        id = vsTan.nextId();
        vm.startPrank(usr);
        deal(address(tan), usr, amount);
        tan.approve(address(vsTan), MAX_UINT);
        vsTan.createLock(amount, perma);
        vm.stopPrank();
    }

    function _process(IERC20 token, uint256 amount) internal {
        vm.startPrank(owner);
        deal(address(token), owner, amount);
        token.approve(address(vsTan), MAX_UINT);
        TokenAmount[] memory t = new TokenAmount[](1);
        t[0] = TokenAmount({token: token, amount: amount});
        vsTan.processRewards(t);
        vm.stopPrank();
    }

    /// M-01: a reward token reverting on transfer to the user locks the TAN principal
    function test_poc_blockedRewardToken_locksPrincipal() external {
        BlockableToken blk = new BlockableToken();
        vm.prank(owner);
        vsTan.addNewReward(IERC20(address(blk)));

        uint256 id = _lock(usr1, 1_000 ether, false);

        blk.mint(owner, 1_000 ether);
        vm.startPrank(owner);
        blk.approve(address(vsTan), MAX_UINT);
        TokenAmount[] memory t = new TokenAmount[](1);
        t[0] = TokenAmount({token: IERC20(address(blk)), amount: 1_000 ether});
        vsTan.processRewards(t);
        vm.stopPrank();

        skip(14 weeks);
        blk.setBlocked(usr1, true);

        vm.startPrank(usr1);
        vm.expectRevert("blocked");
        vsTan.unlock(id, false);
        vm.stopPrank();

        // Kick also reverts -> position earns forever, nobody can remove it
        skip(5 weeks);
        vm.expectRevert("blocked");
        vsTan.kickPosition(id, usr2);

        assertEq(tan.balanceOf(address(vsTan)) >= 1_000 ether, true);
    }

    /// L-01: an expired (unlockable at will) position keeps earning like an active one
    function test_poc_expiredPositionKeepsEarning() external {
        uint256 idExpired = _lock(usr1, 1_000 ether, false);
        uint256 idPerma = _lock(usr2, 1_000 ether, true);

        skip(14 weeks); // usr1 lock is over, still counted in totalSupplyVsTan
        _process(usg, 1_000 ether);
        skip(1 weeks);

        uint256 a = vsTan.claimableRewards(idExpired)[0].amount;
        uint256 b = vsTan.claimableRewards(idPerma)[0].amount;
        assertApproxEqAbs(a, b, 1e6, "expired position earns as much as the perma one");
        assertGt(a, 499 ether);
    }

    /// L-02: rewards streamed while totalSupplyVsTan == 0 are stuck forever
    function test_poc_rewardsLostWhenNoLocker() external {
        _process(usg, 7_000 ether);
        skip(3 days);
        uint256 id = _lock(usr1, 1_000 ether, true);
        skip(1 weeks);

        uint256 claimable = vsTan.claimableRewards(id)[0].amount;
        assertApproxEqAbs(claimable, 4_000 ether, 1e12, "3 days of rewards lost");
        vm.prank(usr1);
        vsTan.claimSimple(id, false);
        assertApproxEqAbs(usg.balanceOf(address(vsTan)), 3_000 ether, 1e12, "stuck, no sweep");
    }

    /// M-02 fixed: a position can't be transferred during the cooldown following a split/claim/toggle
    function test_splitBeforeSale_blockedByCooldown() external {
        uint256 id = _lock(usr1, 10_000 ether, false);
        vm.startPrank(usr1);
        vsTan.split(id, 9_900 ether);
        vm.expectRevert(VsTAN.TransferCooldown.selector);
        vsTan.transferFrom(usr1, usr2, id);

        // New position from the split is transferable, and the original one after the cooldown
        vsTan.transferFrom(usr1, usr2, id + 1);
        skip(vsTan.TRANSFER_COOLDOWN());
        vsTan.transferFrom(usr1, usr2, id);
        vm.stopPrank();
    }

    /// Lock time increase (merge / increaseLockTime / increaseLockAmount) also triggers the cooldown
    function test_lockTimeIncrease_blockedByCooldown() external {
        uint256 a = _lock(usr1, 1_000 ether, false);
        skip(2 weeks);
        uint256 b = _lock(usr1, 1_000 ether, false);
        skip(vsTan.TRANSFER_COOLDOWN());

        vm.startPrank(usr1);
        vsTan.merge(a, b, false);
        vm.expectRevert(VsTAN.TransferCooldown.selector);
        vsTan.transferFrom(usr1, usr2, a);

        skip(1 weeks);
        vsTan.increaseLockTime(a);
        vm.expectRevert(VsTAN.TransferCooldown.selector);
        vsTan.transferFrom(usr1, usr2, a);

        skip(vsTan.TRANSFER_COOLDOWN());
        deal(address(tan), usr1, 1 ether);
        vsTan.increaseLockAmount(a, 1 ether);
        vm.expectRevert(VsTAN.TransferCooldown.selector);
        vsTan.transferFrom(usr1, usr2, a);
        vm.stopPrank();
    }
}
