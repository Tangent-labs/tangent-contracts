// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0;

interface IUpgradeableBeacon {
    function upgradeTo(address newImplementation) external;
}
