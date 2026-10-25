// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MerkleDistributor} from "../../../src/USG/Utilities/MerkleDistributor.sol";

contract MerkleDistributorTest is Test {
    ERC20Mock token;
    MerkleDistributor distributor;

    address[4] users = [makeAddr("alice"), makeAddr("bob"), makeAddr("carol"), makeAddr("dave")];
    uint256[4] amounts = [100 ether, 250 ether, 50 ether, 1_000 ether];
    bytes32[][] proofs;

    function setUp() public {
        bytes32 root;
        (root, proofs) = _ffiMerkleTree();

        token = new ERC20Mock();
        distributor = new MerkleDistributor(token, root);
        token.mint(address(distributor), 1_400 ether);
    }

    /// @dev Root and proofs from @openzeppelin/merkle-tree StandardMerkleTree.
    function _ffiMerkleTree() internal returns (bytes32, bytes32[][] memory) {
        string memory accountsArg;
        string memory amountsArg;
        for (uint256 i; i < 4; i++) {
            string memory sep = i == 0 ? "" : ",";
            accountsArg = string.concat(accountsArg, sep, vm.toString(users[i]));
            amountsArg = string.concat(amountsArg, sep, vm.toString(amounts[i]));
        }

        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "./js-scripts/ffi/merkle/printMerkleTree.mjs";
        inputs[2] = accountsArg;
        inputs[3] = amountsArg;
        return abi.decode(vm.ffi(inputs), (bytes32, bytes32[][]));
    }

    function test_allUsersClaim() public {
        for (uint256 i; i < 4; i++) {
            distributor.claim(users[i], amounts[i], proofs[i]);
            assertEq(token.balanceOf(users[i]), amounts[i]);
            assertTrue(distributor.isClaimed(users[i]));
        }
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    function test_revertsOnDoubleClaim() public {
        distributor.claim(users[1], amounts[1], proofs[1]);
        vm.expectRevert(MerkleDistributor.AlreadyClaimed.selector);
        distributor.claim(users[1], amounts[1], proofs[1]);
    }

    function test_revertsOnWrongAmount() public {
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(users[0], amounts[0] + 1, proofs[0]);
    }

    function test_revertsOnWrongAccount() public {
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(users[1], amounts[0], proofs[0]);
    }

    function test_revertsOnWrongProof() public {
        vm.expectRevert(MerkleDistributor.InvalidProof.selector);
        distributor.claim(users[0], amounts[0], proofs[2]);
    }
}
