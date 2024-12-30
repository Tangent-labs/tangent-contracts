// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Strings.sol";
contract LowLevel {
    function bytesToUint256(bytes memory data) public pure returns (uint256) {
        require(data.length <= 32, "Bytes array too long");
        uint256 result;

        for (uint256 i = 0; i < data.length; i++) {
            result = result << 8;
            result |= uint8(data[i]);
        }
        return result;
    }

    function stringToUint(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length - 1; i++) {
            // Vérifier que le caractère est un chiffre
            require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid character");
            result = result * 10 + (uint256(uint8(b[i])) - 48);
        }
        return result;
    }
    function addressToString(address _addr) public pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(_addr)), 20);
    }
    function bytes32ToAddress(bytes32 _bytes32) public pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }

    function addressToBytes32(address _address) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    function _tStoreBoolForBytes32(bytes32 location, bool value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tLoadBoolForBytes32(bytes32 location) private view returns (bool value) {
        assembly {
            value := tload(location)
        }
    }

    function getNext32Bytes(bytes memory data) public pure returns (bytes32) {
        require(data.length >= 0 + 32, "Insufficient bytes for slicing");

        bytes32 result;
        assembly {
            result := mload(add(add(data, 0x20), 0))
        }

        return result;
    }

    function removeFirst4Bytes(bytes memory data) public pure returns (bytes memory) {
        require(data.length > 4, "Data must be longer than 4 bytes");

        // Créer un nouveau tableau de bytes avec une longueur réduite de 4 octets
        bytes memory result = new bytes(data.length - 4);

        // Copier les octets après les 4 premiers dans le nouveau tableau
        for (uint256 i = 4; i < data.length; i++) {
            result[i - 4] = data[i];
        }

        return result;
    }
}
