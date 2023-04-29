// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

library StringUtils {
    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    function checkAlphaNumeric(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        // if(b.length < 4) 
        //     return false;

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if(
                !(char >= 0x30 && char <= 0x39) &&  //9-0
                !(char >= 0x41 && char <= 0x5A) &&  //A-Z
                !(char >= 0x61 && char <= 0x7A) &&  //a-z
                !(char == 0x2D)                     // -
                // !(char == 0x2E) //.
            )
                return false;
        }
        return true;
    }

    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character...
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                // So we add 32 to make it lowercase
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function concatenate(
        string memory _name,
        string memory _tld
    ) internal pure returns (string memory) {
        // for DappsDns
        // return string(abi.encodePacked(_name, _tld));
        // for DappsDnsNew
        return string(abi.encodePacked(_name, ".", _tld));
    }
}