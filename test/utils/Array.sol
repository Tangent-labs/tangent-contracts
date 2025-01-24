// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library Array {
    function memoryAddress(address[1] memory addresses) public pure returns (address[] memory) {
        address[] memory array = new address[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryAddress(address[2] memory addresses) public pure returns (address[] memory) {
        address[] memory array = new address[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryAddress(address[3] memory addresses) public pure returns (address[] memory) {
        address[] memory array = new address[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryAddress(address[5] memory addresses) public pure returns (address[] memory) {
        address[] memory array = new address[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryIERC20(IERC20Metadata[1] memory addresses) public pure returns (IERC20Metadata[] memory) {
        IERC20Metadata[] memory array = new IERC20Metadata[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryIERC20(IERC20Metadata[2] memory addresses) public pure returns (IERC20Metadata[] memory) {
        IERC20Metadata[] memory array = new IERC20Metadata[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryIERC20(IERC20Metadata[3] memory addresses) public pure returns (IERC20Metadata[] memory) {
        IERC20Metadata[] memory array = new IERC20Metadata[](addresses.length);
        for (uint i = 0; i < addresses.length; i++) {
            array[i] = addresses[i];
        }
        return array;
    }

    function memoryUint256(uint256[1] memory uints) public pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](uints.length);
        for (uint256 i = 0; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint256(uint256[2] memory uints) public pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](uints.length);
        for (uint i = 0; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint256(uint256[3] memory uints) public pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](uints.length);
        for (uint256 i = 0; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint256(uint256[5] memory uints) public pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](uints.length);
        for (uint256 i = 0; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint8(uint8[1] memory uints) public pure returns (uint8[] memory) {
        uint8[] memory array = new uint8[](uints.length);
        for (uint256 i; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint8(uint8[2] memory uints) public pure returns (uint8[] memory) {
        uint8[] memory array = new uint8[](uints.length);
        for (uint256 i; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryUint8(uint8[3] memory uints) public pure returns (uint8[] memory) {
        uint8[] memory array = new uint8[](uints.length);
        for (uint256 i; i < uints.length; i++) {
            array[i] = uints[i];
        }
        return array;
    }

    function memoryBytes4(bytes4[1] memory bytess) public pure returns (bytes4[] memory) {
        bytes4[] memory array = new bytes4[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes4(bytes4[2] memory bytess) public pure returns (bytes4[] memory) {
        bytes4[] memory array = new bytes4[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes4(bytes4[3] memory bytess) public pure returns (bytes4[] memory) {
        bytes4[] memory array = new bytes4[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes32(bytes32[1] memory bytess) public pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes32(bytes32[2] memory bytess) public pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes32(bytes32[3] memory bytess) public pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }

    function memoryBytes32(bytes32[4] memory bytess) public pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }
    function memoryBytes32(bytes32[5] memory bytess) public pure returns (bytes32[] memory) {
        bytes32[] memory array = new bytes32[](bytess.length);
        for (uint256 i; i < bytess.length; i++) {
            array[i] = bytess[i];
        }
        return array;
    }
}
