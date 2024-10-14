import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../src/libs/Resources.sol";

contract AssertERC20 is Test {
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
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: 0, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    function verifyBalERC20NotChanging(IERC20 erc20, address acc) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: 0, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: ""})
        );
    }

    function verifySupplyERC20NotChanging(IERC20 erc20, string memory reason) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: 0, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    function verifySupplyERC20NotChanging(IERC20 erc20) public {
        burnChanges.push(SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: 0, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""}));
    }

    ////

    function verifyReceiveERC20(IERC20 erc20, address acc, uint256 amount, string memory reason) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    function verifyLostERC20(IERC20 erc20, address acc, uint256 amount, string memory reason) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    function verifyMintERC20(IERC20 erc20, uint256 amount, string memory reason) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    function verifyBurnERC20(IERC20 erc20, uint256 amount, string memory reason) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: reason})
        );
    }

    //////

    function verifyReceiveERC20(IERC20 erc20, address acc, uint256 amount) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: ""})
        );
    }

    function verifyLostERC20(IERC20 erc20, address acc, uint256 amount) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: 0, reason: ""})
        );
    }

    function verifyMintERC20(IERC20 erc20, uint256 amount) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""})
        );
    }

    function verifyBurnERC20(IERC20 erc20, uint256 amount) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: 0, reason: ""})
        );
    }

    /////

    function verifyReceiveDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel, string memory reason) public {
        receiveChanges.push(
            BalChange({
                erc20: IERC20Metadata(address(erc20)),
                acc: acc,
                amount: amount,
                bal: erc20.balanceOf(acc),
                deltaAbs: 0,
                deltaRel: deltaRel,
                reason: reason
            })
        );
    }

    function verifyLostDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel, string memory reason) public {
        lostChanges.push(
            BalChange({
                erc20: IERC20Metadata(address(erc20)),
                acc: acc,
                amount: amount,
                bal: erc20.balanceOf(acc),
                deltaAbs: 0,
                deltaRel: deltaRel,
                reason: reason
            })
        );
    }

    function verifyMintDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel, string memory reason) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: reason})
        );
    }

    function verifyBurnDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel, string memory reason) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: reason})
        );
    }

    ///

    function verifyReceiveDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: deltaRel, reason: ""})
        );
    }

    function verifyLostDeltaRelERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaRel) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: 0, deltaRel: deltaRel, reason: ""})
        );
    }

    function verifyMintDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: ""})
        );
    }

    function verifyBurnDeltaRelERC20(IERC20 erc20, uint256 amount, uint256 deltaRel) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: 0, deltaRel: deltaRel, reason: ""})
        );
    }

    ///

    function verifyReceiveDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs, string memory reason) public {
        receiveChanges.push(
            BalChange({
                erc20: IERC20Metadata(address(erc20)),
                acc: acc,
                amount: amount,
                bal: erc20.balanceOf(acc),
                deltaAbs: deltaAbs,
                deltaRel: 0,
                reason: reason
            })
        );
    }

    function verifyLostDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs, string memory reason) public {
        lostChanges.push(
            BalChange({
                erc20: IERC20Metadata(address(erc20)),
                acc: acc,
                amount: amount,
                bal: erc20.balanceOf(acc),
                deltaAbs: deltaAbs,
                deltaRel: 0,
                reason: reason
            })
        );
    }

    function verifyMintDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs, string memory reason) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: reason})
        );
    }

    function verifyBurnDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs, string memory reason) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: reason})
        );
    }

    /////////////////////

    function verifyReceiveDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs) public {
        receiveChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: deltaAbs, deltaRel: 0, reason: ""})
        );
    }

    function verifyLostDeltaAbsERC20(IERC20 erc20, address acc, uint256 amount, uint256 deltaAbs) public {
        lostChanges.push(
            BalChange({erc20: IERC20Metadata(address(erc20)), acc: acc, amount: amount, bal: erc20.balanceOf(acc), deltaAbs: deltaAbs, deltaRel: 0, reason: ""})
        );
    }

    function verifyMintDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs) public {
        mintChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: ""})
        );
    }

    function verifyBurnDeltaAbsERC20(IERC20 erc20, uint256 amount, uint256 deltaAbs) public {
        burnChanges.push(
            SupplyChange({erc20: IERC20Metadata(address(erc20)), amount: amount, supply: erc20.totalSupply(), deltaAbs: deltaAbs, deltaRel: 0, reason: ""})
        );
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

    function _assertBalanceChanges() internal {
        for (uint256 index = 0; index < receiveChanges.length; index++) {
            BalChange memory bal = receiveChanges[index];
            uint256 newBalance = bal.erc20.balanceOf(bal.acc);
            string memory symbol = vm.getLabel(address(bal.erc20));
            uint256 realAmount;

            assertTrue(newBalance >= bal.bal, string.concat("The balance in ", symbol, " of ", vm.getLabel(bal.acc), " decreased instead of increase"));
            realAmount = newBalance - bal.bal;
            if (bytes(bal.reason).length == 0) {
                bal.reason = string.concat(
                    vm.getLabel(bal.acc),
                    " received ",
                    vm.toString(realAmount),
                    " of ",
                    symbol,
                    " instead of ",
                    vm.toString(bal.amount),
                    " "
                );
            }
            if (bal.amount == 0) {}

            _assertEqOrAbsOrRel(realAmount, bal.amount, bal.deltaAbs, bal.deltaRel, bal.reason);
        }

        for (uint256 index = 0; index < lostChanges.length; index++) {
            BalChange memory bal = lostChanges[index];
            uint256 newBalance = bal.erc20.balanceOf(bal.acc);
            string memory symbol = vm.getLabel(address(bal.erc20));
            uint256 realAmount;

            assertTrue(newBalance <= bal.bal, string.concat("The balance in ", symbol, " of ", vm.getLabel(bal.acc), " increased instead of deacrease"));

            realAmount = bal.bal - newBalance;

            if (bytes(bal.reason).length == 0) {
                bal.reason = string.concat(
                    vm.getLabel(bal.acc),
                    " sent ",
                    vm.toString(realAmount),
                    " of ",
                    symbol,
                    " instead of ",
                    vm.toString(bal.amount),
                    " "
                );
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

    // function getBalances(BalancesChange[] memory lostChanges) public view returns (BalancesChange[] memory) {
    //     for (uint256 index = 0; index < lostChanges.length; index++) {
    //         BalancesChange memory bal = lostChanges[index];
    //         IERC20 erc20 = bal.erc20;
    //         // We check the mint
    //         if (bal.from == address(0)) {
    //             bal.balFrom = erc20.totalSupply();
    //         } else {
    //             bal.balFrom = erc20.balanceOf(bal.from);
    //         }
    //         // Burn
    //         if (bal.to == address(0)) {
    //             bal.balTo = erc20.totalSupply();
    //         } else {
    //             bal.balTo = erc20.balanceOf(bal.to);
    //         }
    //     }
    //     return lostChanges;
    // }
    // function assertTransfers(Vm.Log[] memory logss, Transfers[] memory transfersToAssert) public {
    //     uint256 logsLength = logss.length;
    //     for (uint256 index = 0; index < logss.length; ) {
    //         uint256 len = logss.length;
    //         if (len != 1) {
    //             logss[index] = logss[len - 1];
    //             assembly {
    //                 // Réduire la taille du tableau de 1
    //                 mstore(logss, sub(len, 1))
    //             }
    //         } else {
    //             index++;
    //         }
    //     }

    //     // Converts all logs
    //     for (uint256 index = 0; index < logss.length; index++) {
    //         Vm.Log memory logg = logss[index];
    //         bytes32 key = keccak256(abi.encodePacked(logg.emitter, bytes32ToAddress(logg.topics[1]), bytes32ToAddress(logg.topics[2]), logg.data));
    //         _tStoreBoolForBytes32(key, true);
    //     }

    //     // Verify all expect
    //     for (uint256 i = 0; i < transfersToAssert.length; i++) {
    //         Transfers memory t = transfersToAssert[i];
    //         bytes32 aa = keccak256(abi.encodePacked(t.erc20, t.from, t.to, abi.encode(t.amount)));
    //         assertEq(
    //             _tLoadBoolForBytes32(aa),
    //             true,
    //             string.concat("Transfer from ", vm.toString(t.from), " to ", vm.toString(t.to), " of amount : ", vm.toString(t.amount), " didn't occur")
    //         );
    //     }

    //     console.log(logss.length);
    //     vm.stopPrank();
    // }

    // function addERC20Tracking(IERC20 erc20, address from, address to, uint256 amount, string memory reason) public {
    //     uint256 balFrom = from == address(0) ? erc20.totalSupply() : erc20.balanceOf(from);
    //     uint256 balTo = to == address(0) ? erc20.totalSupply() : erc20.balanceOf(to);
    //     balFromToChanges.push(BalancesFromToChange({erc20: erc20, from: from, to: to, balFrom: balFrom, balTo: balTo, amount: amount, reason: reason}));
    // }

    // function _assertBalanceFromToChanges() internal {
    //     for (uint256 index = 0; index < balFromToChanges.length; index++) {
    //         BalancesFromToChange memory bal = balFromToChanges[index];
    //         IERC20 erc20 = bal.erc20;
    //         // Mint
    //         if (bal.from == address(0)) {
    //             assertEq(erc20.totalSupply() - bal.balFrom, bal.amount, string.concat("FROM : ", bal.reason));
    //         } else {
    //             assertEq(bal.balFrom - erc20.balanceOf(bal.from), bal.amount, string.concat("FROM : ", bal.reason));
    //         }
    //         // Burn
    //         if (bal.to == address(0)) {
    //             assertEq(bal.balTo - erc20.totalSupply(), bal.amount, string.concat("TO : ", bal.reason));
    //         } else {
    //             assertEq(erc20.balanceOf(bal.to) - bal.balTo, bal.amount, string.concat("TO : ", bal.reason));
    //         }
    //     }

    //     delete balFromToChanges;
    // }
}
