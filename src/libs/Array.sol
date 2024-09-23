// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Array {
    function createMemoryArray(address[] memory addresses) public pure returns (address[] memory) {
        address[] memory array = new address[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function createMemoryAddressArray() public pure returns (address[] memory) {
        address[] memory array = abi.decode(
            abi.encode([address(0x0000000000000000000000000000000000000001), address(0x0000000000000000000000000000000000000002)]),
            (address[])
        );
        return array;
    }
}
