// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @notice One-time airdrop: each address in the Merkle tree claims its amount once.
/// @dev Tree built with @openzeppelin/merkle-tree: StandardMerkleTree.of(values, ["address", "uint256"]).
contract MerkleDistributor {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;

    mapping(address => bool) public isClaimed;

    event Claimed(address indexed account, uint256 amount);

    error AlreadyClaimed();
    error InvalidProof();

    constructor(IERC20 token_, bytes32 merkleRoot_) {
        token = token_;
        merkleRoot = merkleRoot_;
    }

    function claim(address account, uint256 amount, bytes32[] calldata proof) external {
        if (isClaimed[account]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        isClaimed[account] = true;
        token.safeTransfer(account, amount);

        emit Claimed(account, amount);
    }
}
