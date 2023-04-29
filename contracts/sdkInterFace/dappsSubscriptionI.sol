// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


// interface sdk for using dapps through smart contract
interface SubscriptionModuleI {

    struct Dapp {
        string appName;
        bytes32 appId;
        address appAdmin; //primary
        string appUrl;
        string appIcon;
        string appSmallDescription;
        string appLargeDescription;
        string appCoverImage;
        string[] appScreenshots; // upto 5
        string[] appCategory; // upto 7
        string[] appTags; // upto 7
        string[] appSocial;
        bool isVerifiedDapp; // true or false
        uint256 credits;
        uint256 renewalTimestamp;  
        
         }

// function to check whether a user _user has subscribe a particular dapp with dapp id _dappId or not
  function isSubscribed(bytes32 _dappId, uint256 listID, address _user) view external returns (bool);

  function addNewDapp( Dapp memory _dapp, address _user)  external;
  
function subscribeWithPermit(
   address user,
        bytes32 appID,
        uint256[] memory _lists,
        bool subscriptionStatus,
        uint256 deadline,
        bytes32 r,
        bytes32 s,
        uint8 v
)  external;

  function subscribeToDapp(
         address user,
        bytes32 appID,
        bool subscriptionStatus,
        bool isOauthUser,
        uint256[] memory _lists)  external ;

   function sendAppNotification(
        bytes32 _appId,
        address walletAddress,
        string memory _message,
        string memory buttonName,
        string memory _cta,
        bool _isEncrypted,
        bool isOauthUser
    )
        external;

}


