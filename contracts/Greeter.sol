//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Greeter is OwnableUpgradeable {
    mapping(address=> string) public greetings;

    function __Greeter_init() public initializer {
        __Ownable_init();
    }

    function greet() public view returns (string memory) {
        return greetings[_msgSender()];
    }

    function setGreeting(string memory _greeting) public {
        greetings[_msgSender()] = _greeting;
    }
}
