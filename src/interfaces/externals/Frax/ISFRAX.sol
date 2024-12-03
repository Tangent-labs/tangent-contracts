// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ISFRAX is IERC4626 {
    function syncRewardsAndDistribution() external;
}
