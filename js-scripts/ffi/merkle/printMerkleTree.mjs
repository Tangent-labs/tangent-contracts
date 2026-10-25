import {StandardMerkleTree} from "@openzeppelin/merkle-tree";
import {AbiCoder} from "ethers";

// args: comma-separated accounts, comma-separated amounts
// prints abi.encode(bytes32 root, bytes32[][] proofs), proofs in input order
const accounts = process.argv[2].split(",");
const amounts = process.argv[3].split(",");

const tree = StandardMerkleTree.of(
    accounts.map((account, i) => [account, amounts[i]]),
    ["address", "uint256"],
);
const proofs = accounts.map((_, i) => tree.getProof(i));

process.stdout.write(AbiCoder.defaultAbiCoder().encode(["bytes32", "bytes32[][]"], [tree.root, proofs]));
