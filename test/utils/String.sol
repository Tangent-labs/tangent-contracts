// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
library String {
    function toDecimalString(uint256 value, uint8 decimals) public pure returns (string memory) {
        if (decimals == 0) return _toString(value);

        uint256 base = 10 ** decimals;
        uint256 integerPart = value / base;
        uint256 fractionalPart = value % base;

        // Convert integer part to string
        string memory intStr = _toString(integerPart);

        // Convert fractional part to string, pad with leading zeroes
        string memory fracStr = _toString(fractionalPart);
        uint256 fracLen = bytes(fracStr).length;

        if (fractionalPart == 0) {
            // Return without trailing decimals
            return string(abi.encodePacked(intStr, ".0"));
        }

        // Pad with leading zeroes to match decimals
        string memory leadingZeros = "";
        for (uint256 i = fracLen; i < decimals; i++) {
            leadingZeros = string(abi.encodePacked(leadingZeros, "0"));
        }

        return string(abi.encodePacked(intStr, ".", leadingZeros, fracStr));
    }

    function _toString(uint256 value) internal pure returns (string memory str) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
