// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

interface IStashTokenWrapper is IERC20Metadata {
    function token() external view returns (IERC20Metadata);
}
