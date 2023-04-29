// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISubscriptionModule {
    
    function isSubscribed(
        bytes32 _dappId,
        uint256 listID,
        address _user
    ) external view returns (bool);

    function getDappAdmin(bytes32 _dappId) external view returns (address);

    function getPrimaryFromSecondary(address _account) external view returns (address);
}
