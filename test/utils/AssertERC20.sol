import {Test} from "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AssertERC20 is Test {
    uint256 public constant MAX_UINT = uint256(int256(-1));
    uint256 public constant RAY = 1e27;
    BalChange[] receiveChanges;
    BalChange[] lostChanges;
    BalChange[] noBalChanges;

    SupplyChange[] mintChanges;
    SupplyChange[] burnChanges;
    SupplyChange[] noSupplyChanges;

    struct Transfers {
        IERC20 erc20;
        address from;
        address to;
        uint256 amount;
    }

    struct BalChange {
        IERC20Metadata erc20;
        uint256 bal;
        address acc;
        uint256 amount;
        uint256 deltaAbs;
        uint256 deltaRel;
        string reason;
    }

    struct SupplyChange {
        IERC20Metadata erc20;
        uint256 supply;
        uint256 amount;
        uint256 deltaAbs;
        uint256 deltaRel;
        string reason;
    }

    function verifyBalERC20NotChanging(IERC20 erc20, address acc, string memory reason) public {
        receiveChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: 0, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    function verifyBalERC20NotChanging(IERC20 erc20, address acc) public {
        receiveChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: 0, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    function verifySupplyERC20NotChanging(IERC20 erc20, string memory reason) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: 0, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    function verifySupplyERC20NotChanging(IERC20 erc20) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: 0, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    ////

    function verifyReceiveERC20(IERC20 erc20, address acc, uint256 amount, string memory reason) public {
        receiveChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    function verifyLostERC20(IERC20 erc20, address acc, uint256 amount, string memory reason) public {
        lostChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    function verifyMintERC20(IERC20 erc20, uint256 amount, string memory reason) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    function verifyBurnERC20(IERC20 erc20, uint256 amount, string memory reason) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason}));
    }

    //////

    function verifyReceiveERC20(IERC20 erc20, address acc, uint256 amount) public {
        receiveChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    function verifyLostERC20(IERC20 erc20, address acc, uint256 amount) public {
        lostChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    function verifyMintERC20(IERC20 erc20, uint256 amount) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    function verifyBurnERC20(IERC20 erc20, uint256 amount) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    /////

    function verifyReceiveDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel, string memory reason) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: deltaRel, reason: reason})
        );
    }

    function verifyLostDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel, string memory reason) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: deltaRel, reason: reason})
        );
    }

    function verifyMintDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel, string memory reason) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: reason}));
    }

    function verifyBurnDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel, string memory reason) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: reason}));
    }

    ///

    function verifyReceiveDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: deltaRel, reason: ""})
        );
    }

    function verifyLostDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel) public {
        lostChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: 0, deltaRel: deltaRel, reason: ""}));
    }

    function verifyMintDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: ""}));
    }

    function verifyBurnDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: ""}));
    }

    ///

    function verifyReceiveDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs, string memory reason) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: deltaAbs, deltaRel: 0, reason: reason})
        );
    }

    function verifyLostDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs, string memory reason) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: deltaAbs, deltaRel: 0, reason: reason})
        );
    }

    function verifyMintDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs, string memory reason) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: reason}));
    }

    function verifyBurnDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs, string memory reason) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: reason}));
    }

    /////////////////////

    function verifyReceiveDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: deltaAbs, deltaRel: 0, reason: ""})
        );
    }

    function verifyLostDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs) public {
        lostChanges.push(BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: _getBalance(erc20, acc), deltaAbs: deltaAbs, deltaRel: 0, reason: ""}));
    }

    function verifyMintDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs) public {
        mintChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: ""}));
    }

    function verifyBurnDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: ""}));
    }

    function assertERC20Tracking() public {
        _assertSupplyChanges();
        _assertBalanceChanges();
    }

    function _assertEqOrAbsOrRel(uint256 realAmount, uint256 expectedAmount, uint256 deltaAbs, uint256 deltaRel, string memory reason) internal pure {
        if (deltaAbs != 0) {
            assertApproxEqAbs(realAmount, expectedAmount, deltaAbs, reason);
        } else if (deltaRel != 0) {
            assertApproxEqRel(realAmount, expectedAmount, deltaRel, reason);
        } else {
            assertEq(realAmount, expectedAmount, reason);
        }
    }

    function _getBalance(IERC20 erc20, address acc) internal view returns (uint256) {
        return (address(erc20) != address(0) && address(erc20) != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) ? erc20.balanceOf(acc) : acc.balance;
    }

    function _assertBalanceChanges() internal {
        for (uint256 index = 0; index < receiveChanges.length; index++) {
            BalChange memory bal = receiveChanges[index];
            uint256 newBalance = _getBalance(bal.erc20, bal.acc);
            string memory symbol = vm.getLabel(address(bal.erc20));
            uint256 realAmount;

            assertTrue(newBalance >= bal.bal, string.concat("The balance in ", symbol, " of ", vm.getLabel(bal.acc), " decreased instead of increase"));
            realAmount = newBalance - bal.bal;
            if (bytes(bal.reason).length == 0) {
                bal.reason = string.concat(vm.getLabel(bal.acc), " received ", vm.toString(realAmount), " of ", symbol, " instead of ", vm.toString(bal.amount), " ");
            }
            if (bal.amount == 0) {}

            _assertEqOrAbsOrRel(realAmount, bal.amount, bal.deltaAbs, bal.deltaRel, bal.reason);
        }

        for (uint256 index = 0; index < lostChanges.length; index++) {
            BalChange memory bal = lostChanges[index];
            uint256 newBalance = _getBalance(bal.erc20, bal.acc);
            string memory symbol = vm.getLabel(address(bal.erc20));
            uint256 realAmount;

            assertTrue(newBalance <= bal.bal, string.concat("The balance in ", symbol, " of ", vm.getLabel(bal.acc), " increased instead of deacrease"));

            realAmount = bal.bal - newBalance;

            if (bytes(bal.reason).length == 0) {
                bal.reason = string.concat(vm.getLabel(bal.acc), " sent ", vm.toString(realAmount), " of ", symbol, " instead of ", vm.toString(bal.amount), " ");
            }

            _assertEqOrAbsOrRel(realAmount, bal.amount, bal.deltaAbs, bal.deltaRel, bal.reason);
        }

        delete receiveChanges;
        delete lostChanges;
    }

    function _assertSupplyChanges() internal {
        for (uint256 index = 0; index < mintChanges.length; index++) {
            SupplyChange memory sup = mintChanges[index];
            uint256 newSupply = sup.erc20.totalSupply();
            string memory symbol = vm.getLabel(address(sup.erc20));
            uint256 realAmount;

            assertTrue(newSupply >= sup.supply, string.concat("The supply of ", symbol, " decreased instead of increase "));
            realAmount = newSupply - sup.supply;
            if (bytes(sup.reason).length == 0) {
                sup.reason = string.concat(vm.toString(realAmount), " ", symbol, " minted instead of ", vm.toString(sup.amount), " ");
            }

            _assertEqOrAbsOrRel(realAmount, sup.amount, sup.deltaAbs, sup.deltaRel, sup.reason);
        }

        for (uint256 index = 0; index < burnChanges.length; index++) {
            SupplyChange memory sup = burnChanges[index];
            uint256 newSupply = sup.erc20.totalSupply();
            string memory symbol = vm.getLabel(address(sup.erc20));
            uint256 realAmount;

            assertTrue(newSupply <= sup.supply, string.concat("The supply of ", symbol, " increased instead of decrease "));
            realAmount = sup.supply - newSupply;
            if (bytes(sup.reason).length == 0) {
                sup.reason = string.concat(vm.toString(realAmount), " ", symbol, " burnt instead of ", vm.toString(sup.amount), " ");
            }

            _assertEqOrAbsOrRel(realAmount, sup.amount, sup.deltaAbs, sup.deltaRel, sup.reason);
        }
        delete mintChanges;
        delete burnChanges;
    }
}
