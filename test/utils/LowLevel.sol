// SPDX-License-Identifier: MIT
contract LowLevel {
    function bytes32ToAddress(bytes32 _bytes32) public pure returns (address) {
        return address(uint160(uint256(_bytes32)));
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
