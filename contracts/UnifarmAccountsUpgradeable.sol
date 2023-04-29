// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./GasRestrictor.sol";
import "./Gamification.sol";

contract UnifarmAccountsUpgradeable is Initializable, OwnableUpgradeable {
    uint256 public chainId;
    uint256 public defaultCredits;
    uint256 public renewalPeriod;
    GasRestrictor public gasRestrictor;
    Gamification public gamification;



    // --------------------- DAPPS STORAGE -----------------------

    struct Role {
        bool sendNotificationRole;
        bool addAdminRole;
    }
    struct SecondaryWallet {
        address account;
        string encPvtKey;
        string publicKey;
    }

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
        // string[] appTokens;
        bool isVerifiedDapp; // true or false
        uint256 credits;
        uint256 renewalTimestamp;
  
        
    }

//     struct reaction {
//         string reactionName;
//         uint count;
//     }

//     struct tokenNotif {
//     string message;
//     reaction[] reactions;
//     uint reactionCounts;
//     }
// // token address => tokenNotif 
//     mapping(address=>tokenNotif[]) public tokenNotifs;

    struct Notification {
        bytes32 appID;
        address walletAddressTo; // primary
        string message;
        string buttonName;
        string cta;
        uint256 timestamp;
        bool isEncrypted;
    }
    mapping(bytes32 => Dapp) public dapps;

    // all dapps count
    uint256 public dappsCount;
    uint256 public verifiedDappsCount;

    mapping(address => Notification[]) public notificationsOf;

    // dappId => count
    mapping(bytes32 => uint256) public notificationsCount;

    // dappId => count
    mapping(bytes32 => uint256) public subscriberCount;

    // user=>subscribeAppsCount
    mapping(address => uint256) public subscriberCountUser;
    mapping(address => uint256) public appCountUser;

    // address => dappId  => role
    mapping(address => mapping(bytes32 => Role)) public roleOfAddress;

    // dappId => address => bool(true/false)
    mapping(bytes32 => mapping(address => bool)) public isSubscribed;

    // userAddress  => Wallet
    mapping(address => SecondaryWallet) public userWallets;
    // string => userWallet for email users
    mapping(string => SecondaryWallet) public oAuthUserWallets;

    // secondary to primary wallet mapping to get primary wallet from secondary
    mapping(address => address) public getPrimaryFromSecondary;

    // dappID => telegram chatID
    mapping(address => string) public telegramChatID;

    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 public constant SUBSC_PERMIT_TYPEHASH =
        keccak256(
            "SubscPermit(address user,bytes32 appID,bool subscriptionStatus,uint256 nonce,uint256 deadline)"
        );
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public DOMAIN_SEPARATOR = keccak256(abi.encode(
    //     EIP712_DOMAIN_TYPEHASH,
    //     keccak256(bytes("Dapps")),
    //     keccak256(bytes("1")),
    //     chainId,
    //     address(this)
    // ));

    mapping(address => uint256) public nonce;

    uint256 public noOfWallets;
    uint256 public noOfSubscribers;
    uint256 public noOfNotifications;

  

    modifier onlySuperAdmin() {
        _onlySuperAdmin();
        _;
    }
    modifier isValidSender(address from) {
       _isValidSender(from);
        _;
    }


    modifier superAdminOrDappAdmin(bytes32 appID) {
       _superAdminOrDappAdmin(appID);
       _;
    }

    modifier superAdminOrDappAdminOrAddedAdmin(bytes32 appID) {
       _superAdminOrDappAdminOrAddedAdmin(appID);
        _;
    }

    modifier superAdminOrDappAdminOrSendNotifRole(bytes32 appID) {
       _superAdminOrDappAdminOrSendNotifRole(appID);
        _;
    }

    modifier GasNotZero(address user, bool isOauthUser) {
        _gasNotZero(user, isOauthUser);
        _;
    }

    event WalletCreated(
        address indexed account,
        address secondaryAccount,
        bool isOAuthUser,
        string oAuthEncryptedUserId,
        uint256 walletCount
    );

    event NewAppRegistered(
        bytes32 appID,
        address appAdmin,
        string appName,
        uint256 dappCount
    );

    event AppUpdated(bytes32 appID);

    event AppRemoved(bytes32 appID, uint256 dappCount);

    event AppAdmin(bytes32 appID, address appAdmin, address admin, uint8 role);

    event AppSubscribed(
        bytes32 appID,
        address subscriber,
        uint256 count,
        uint256 totalCount
    );

    event AppUnSubscribed(
        bytes32 appID,
        address subscriber,
        uint256 count,
        uint256 totalCount
    );

    event NewNotification(
        bytes32 appId,
        address walletAddress,
        string message,
        string buttonName,
        string cta,
        bool isEncrypted,
        uint256 count,
        uint256 totalCount
    );

    function __UnifarmAccounts_init(
        uint256 _chainId,
        uint256 _defaultCredits,
        uint256 _renewalPeriod,
        address _trustedForwarder
    ) public initializer {
        chainId = _chainId;
        defaultCredits = _defaultCredits;
        renewalPeriod = _renewalPeriod;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Dapps")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        __Ownable_init(_trustedForwarder);
    }


  function _onlySuperAdmin() internal view {
         require(
            _msgSender() == owner() ||
                _msgSender() == getSecondaryWalletAccount(owner()),
            "INVALID_SENDER"
        );
    }

      function _superAdminOrDappAdmin(bytes32 _appID) internal view {
         address appAdmin = getDappAdmin(_appID);
        require(
            _msgSender() == owner() ||
                _msgSender() == getSecondaryWalletAccount(owner()) ||
                _msgSender() == appAdmin ||
                _msgSender() == getSecondaryWalletAccount(appAdmin),
            "INVALID_SENDER"
        );
    }
      function _superAdminOrDappAdminOrSendNotifRole(bytes32 _appID) internal view {
      address appAdmin = getDappAdmin(_appID);
        require(
            _msgSender() == owner() ||
                _msgSender() == getSecondaryWalletAccount(owner()) ||
                _msgSender() == appAdmin ||
                _msgSender() == getSecondaryWalletAccount(appAdmin) ||
                roleOfAddress[_msgSender()][_appID].sendNotificationRole == true,
            "INVALID_SENDER"
        );
    }
      function _superAdminOrDappAdminOrAddedAdmin(bytes32 _appID) internal view {
      address appAdmin = getDappAdmin(_appID);
        require(
            _msgSender() == owner() ||
                _msgSender() == getSecondaryWalletAccount(owner()) ||
                _msgSender() == appAdmin ||
                _msgSender() == getSecondaryWalletAccount(appAdmin) ||
                roleOfAddress[_msgSender()][_appID].addAdminRole == true,
            "INVALID_SENDER"
        );
    }

    function _isValidSender(address _from) internal view {
 require(
            _msgSender() == _from ||
                _msgSender() == getSecondaryWalletAccount(_from),
            "INVALID_SENDER"
        );
    }

    // function sendNotifTokenHolders() public {

    // }

    function addGasRestrictorAndGamification(
        GasRestrictor _gasRestrictor,
        Gamification _gamification
    ) external onlyOwner {
        gasRestrictor = _gasRestrictor;
        gamification = _gamification;
    }

    function _gasNotZero(address user, bool isOauthUser) internal view {
        if (isTrustedForwarder[msg.sender]) {
            if (!isOauthUser) {
                if (getPrimaryFromSecondary[user] == address(0)) {} else {
                    (, , uint256 u) = gasRestrictor.gaslessData(
                        getPrimaryFromSecondary[user]
                    );
                    require(u != 0, "NOT_ENOUGH_GASBALANCE");
                }
            } else {
                (, , uint256 u) = gasRestrictor.gaslessData(user);
                require(u != 0, "NOT_ENOUGH_GASBALANCE");
            }
        }
    }

    // -------------------- DAPP FUNCTIONS ------------------------

    function addNewDapp(
        Dapp memory _dapp,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();
        require(_dapp.appAdmin != address(0), "ADMIN CAN'T BE 0 ADDRESS");
        require(_dapp.appScreenshots.length < 6, "SURPASSED IMAGE LIMIT");
        require(_dapp.appCategory.length < 8, "SURPASSED CATEGORY LIMIT");
        require(_dapp.appTags.length < 8, "SURPASSED TAG LIMIT");

        checkFirstApp();
        _addNewDapp(
            _dapp,
            false
        );

        _updateGaslessData(gasLeftInit);
    }

    function _addNewDapp(
        Dapp memory _dapp,
        bool _isAdmin
    ) internal {
        bytes32 _appID;
        Dapp memory dapp = Dapp({
            appName: _dapp.appName,
            appId: _appID,
            appAdmin: _dapp.appAdmin,
            appUrl: _dapp.appUrl,
            appIcon: _dapp.appIcon,
            appCoverImage: _dapp.appCoverImage,
            appSmallDescription: _dapp.appSmallDescription,
            appLargeDescription: _dapp.appLargeDescription,
            appScreenshots: _dapp.appScreenshots,
            appCategory: _dapp.appCategory,
            appTags: _dapp.appTags,
            appSocial: _dapp.appSocial,
            isVerifiedDapp: false,
            credits: defaultCredits,
            renewalTimestamp: block.timestamp
        });
        if(!_isAdmin)
            _appID = keccak256(
                abi.encode(dapp, block.number, _msgSender(), dappsCount, chainId)
            );
        else
            _appID = _dapp.appId;
        dapp.appId = _appID;

        dapps[_appID] = dapp;
        emit NewAppRegistered(_appID, _dapp.appAdmin, _dapp.appName, ++dappsCount);
    }

    function addNewDappOnNewChain(
        Dapp memory _dapp
    ) external onlyOwner {
        // uint256 gasLeftInit = gasleft();
        require(_dapp.appAdmin != address(0), "ADMIN CAN'T BE 0 ADDRESS");
        require(_dapp.appScreenshots.length < 6, "SURPASSED IMAGE LIMIT");
        require(_dapp.appCategory.length < 8, "SURPASSED CATEGORY LIMIT");
        require(_dapp.appTags.length < 8, "SURPASSED TAG LIMIT");
        require(_dapp.appId != "", "INVALID_APP_ID");
        // checkFirstApp();
        _addNewDapp(
            _dapp,
            true
        );

        // _updateGaslessData(gasLeftInit);
    }

    // function addNewDapp(
    //     string memory _appName,
    //     address _appAdmin, //primary
    //     string memory _appUrl,
    //     string memory _appIcon,
    //     string memory _appCoverImage,
    //     string memory _appSmallDescription,
    //     string memory _appLargeDescription,
    //     string[] memory _appScreenshots,
    //     string[] memory _appCategory,
    //     string[] memory _appTags,
    //     string[] memory _appSocial,
    //     bool isOauthUser
    // ) external GasNotZero(_msgSender(), isOauthUser) {
    //     uint256 gasLeftInit = gasleft();
    //     require(_appAdmin != address(0), "ADMIN CAN'T BE 0 ADDRESS");
    //     require(_appScreenshots.length < 6, "SURPASSED IMAGE LIMIT");
    //     require(_appCategory.length < 8, "SURPASSED CATEGORY LIMIT");
    //     require(_appTags.length < 8, "SURPASSED TAG LIMIT");

    //     checkFirstApp();
    //     _addNewDapp(
    //         _appName,
    //         _appAdmin,
    //         _appUrl,
    //         _appIcon,
    //         _appCoverImage,
    //         _appSmallDescription,
    //         _appLargeDescription,
    //         _appScreenshots,
    //         _appCategory,
    //         _appTags,
    //         _appSocial
    //     );

    //     _updateGaslessData(gasLeftInit);
    // }

    // function _addNewDapp(
    //     string memory _appName,
    //     address _appAdmin, //primary
    //     string memory _appUrl,
    //     string memory _appIcon,
    //     string memory _appCoverImage,
    //     string memory _appSmallDescription,
    //     string memory _appLargeDescription,
    //     string[] memory _appScreenshots,
    //     string[] memory _appCategory,
    //     string[] memory _appTags,
    //     string[] memory _appSocial
    // ) internal {
    //     bytes32 _appID;
    //     Dapp memory dapp = Dapp({
    //         appName: _appName,
    //         appId: _appID,
    //         appAdmin: _appAdmin,
    //         appUrl: _appUrl,
    //         appIcon: _appIcon,
    //         appCoverImage: _appCoverImage,
    //         appSmallDescription: _appSmallDescription,
    //         appLargeDescription: _appLargeDescription,
    //         appScreenshots: _appScreenshots,
    //         appCategory: _appCategory,
    //         appTags: _appTags,
    //         appSocial: _appSocial,
    //         isVerifiedDapp: false,
    //         credits: defaultCredits,
    //         renewalTimestamp: block.timestamp
    //     });
    //     _appID = keccak256(
    //         abi.encode(dapp, block.number, _msgSender(), dappsCount, chainId)
    //     );
    //     dapp.appId = _appID;

    //     dapps[_appID] = dapp;
    //     emit NewAppRegistered(_appID, _appAdmin, _appName, ++dappsCount);
    // }

    function checkFirstApp() internal {
        address primary = getPrimaryFromSecondary[_msgSender()];
        if (primary != address(0)) {
            if (appCountUser[primary] == 0) {
                // add 5 karma points of primarywallet
                  gamification.addKarmaPoints(primary, 5);
            }
            appCountUser[primary]++;
        } else {
            if (appCountUser[_msgSender()] == 0) {
                // add 5 karma points of _msgSender()
                  gamification.addKarmaPoints(_msgSender(), 5);

            }
            appCountUser[_msgSender()]++;
        }
    }

    function changeDappAdmin(
        bytes32 _appId,
        address _newAdmin,
        bool isOauthUser
    )
        external
        superAdminOrDappAdmin(_appId)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(dapps[_appId].appAdmin != address(0), "INVALID_DAPP");
        require(_newAdmin != address(0), "INVALID_OWNER");
        dapps[_appId].appAdmin = _newAdmin;

        // if (msg.sender == trustedForwarder)
        //     gasRestrictor._updateGaslessData(_msgSender(), gasLeftInit);
        _updateGaslessData(gasLeftInit);
    }

    function updateDapp(
        bytes32 _appId,
        string memory _appName,
        string memory _appUrl,
        string[] memory _appImages, // [icon, cover_image]
        // string memory _appSmallDescription,
        // string memory _appLargeDescription,
        string[] memory _appDesc, // [small_desc, large_desc]
        string[] memory _appScreenshots,
        string[] memory _appCategory,
        string[] memory _appTags,
        string[] memory _appSocial, // [twitter_url]
        bool isOauthUser
    )
        external
        superAdminOrDappAdminOrAddedAdmin(_appId)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(_appImages.length == 2, "IMG_LIMIT_EXCEED");
        require(_appScreenshots.length < 6, "SS_LIMIT_EXCEED");
        require(_appCategory.length < 8, "CAT_LIMIT_EXCEED");
        require(_appTags.length < 8, "TAG_LIMIT_EXCEED");
        require(_appDesc.length == 2, "DESC_LIMIT_EXCEED");

        // _updateDappTextInfo(_appId, _appName, _appUrl, _appSmallDescription, _appLargeDescription, _appCategory, _appTags, _appSocial);
        _updateDappTextInfo(
            _appId,
            _appName,
            _appUrl,
            _appDesc,
            _appCategory,
            _appTags,
            _appSocial
        );
        _updateDappImageInfo(_appId, _appImages, _appScreenshots);

      // if(isTrustedForwarder(msg.sender)) {
        //     gasRestrictor._updateGaslessData(_msgSender(), gasLeftInit);
        // }
        _updateGaslessData(gasLeftInit);
    }

    function _updateDappTextInfo(
        bytes32 _appId,
        string memory _appName,
        string memory _appUrl,
        // string memory _appSmallDescription,
        // string memory _appLargeDescription,
        string[] memory _appDesc,
        string[] memory _appCategory,
        string[] memory _appTags,
        string[] memory _appSocial
    ) internal {
        Dapp storage dapp = dapps[_appId];
        require(dapp.appAdmin != address(0), "INVALID_DAPP");
        if (bytes(_appName).length != 0) dapp.appName = _appName;
        if (bytes(_appUrl).length != 0) dapp.appUrl = _appUrl;
        if (bytes(_appDesc[0]).length != 0)
            dapp.appSmallDescription = _appDesc[0];
        if (bytes(_appDesc[1]).length != 0)
            dapp.appLargeDescription = _appDesc[1];
        // if(_appCategory.length != 0)
        dapp.appCategory = _appCategory;
        // if(_appTags.length != 0)
        dapp.appTags = _appTags;
        // if(_appSocial.length != 0)
        dapp.appSocial = _appSocial;
    }

    function _updateDappImageInfo(
        bytes32 _appId,
        string[] memory _appImages,
        string[] memory _appScreenshots
    ) internal {
        Dapp storage dapp = dapps[_appId];
        // if(bytes(_appImages[0]).length != 0)
        dapp.appIcon = _appImages[0];
        // if(bytes(_appImages[1]).length != 0)
        dapp.appCoverImage = _appImages[1];
        // if(_appScreenshots.length != 0)
        dapp.appScreenshots = _appScreenshots;

        emit AppUpdated(_appId);
    }

    function removeDapp(bytes32 _appId, bool isOauthUser)
        external
        superAdminOrDappAdmin(_appId)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(dapps[_appId].appAdmin != address(0), "INVALID_DAPP");
        if (dapps[_appId].isVerifiedDapp) --verifiedDappsCount;
        delete dapps[_appId];
        --dappsCount;

        emit AppRemoved(_appId, dappsCount);

        _updateGaslessData(gasLeftInit);
    }

    function subscribeToDapp(
        address user,
        bytes32 appID,
        bool subscriptionStatus,
        bool isOauthUser
    ) external isValidSender(user) GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();
        require(dapps[appID].appAdmin != address(0), "INVALID DAPP ID");
        require(isSubscribed[appID][user] != subscriptionStatus, "UNCHANGED");

        _subscribeToDapp(user, appID, subscriptionStatus);

        // if(isTrustedForwarder(msg.sender)) {
        //     gasRestrictor._updateGaslessData(_msgSender(), gasLeftInit);
        // }
        _updateGaslessData(gasLeftInit);
    }

    function _subscribeToDapp(
        address user,
        bytes32 appID,
        bool subscriptionStatus
    ) internal {
        isSubscribed[appID][user] = subscriptionStatus;

        if (subscriptionStatus) {
            emit AppSubscribed(
                appID,
                user,
                ++subscriberCount[appID],
                ++noOfSubscribers
            );

            if (subscriberCount[appID] == 100) {
                // add 10 karma point to app admin

                gamification.addKarmaPoints(dapps[appID].appAdmin, 10);

            } else if (subscriberCount[appID] == 500) {
                // add 50 karma point to app admin
                gamification.addKarmaPoints(dapps[appID].appAdmin, 50);

            } else if (subscriberCount[appID] == 1000) {
                // add 100 karma point to app admin

                gamification.addKarmaPoints(dapps[appID].appAdmin, 100);


            }

            if (subscriberCountUser[user] == 0) {
                // add 1 karma point to subscriber
                gamification.addKarmaPoints(user, 1);


            } else if (subscriberCountUser[user] == 5) {
                // add 5 karma points to subscriber
                gamification.addKarmaPoints(user, 5);
            }
            subscriberCountUser[user] = subscriberCountUser[user] + 1;
        } else {
            emit AppUnSubscribed(
                appID,
                user,
                --subscriberCount[appID],
                --noOfSubscribers
            );
            if (subscriberCountUser[user] == 0) {
                // remove 1 karma point to app admin
                gamification.removeKarmaPoints(user, 1);
            } else if (subscriberCountUser[user] == 4) {
                // remove 5 karma points to app admin
                gamification.removeKarmaPoints(user, 5);
            }

            if (subscriberCount[appID] == 99) {
                // remove 10 karma point
                gamification.removeKarmaPoints(dapps[appID].appAdmin, 10);
            } else if (subscriberCount[appID] == 499) {
                // remove 50 karma point
                gamification.removeKarmaPoints(dapps[appID].appAdmin, 50);
            } else if (subscriberCount[appID] == 999) {
                // remove 100 karma point
                gamification.removeKarmaPoints(dapps[appID].appAdmin, 100);
            }
        }

        if (address(0) != getSecondaryWalletAccount(user)) {
            isSubscribed[appID][
                getSecondaryWalletAccount(user)
            ] = subscriptionStatus;
        }
    }

    function subscribeWithPermit(
        address user,
        bytes32 appID,
        bool subscriptionStatus,
        uint256 deadline,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(dapps[appID].appAdmin != address(0), "INVALID DAPP ID");
        require(isSubscribed[appID][user] != subscriptionStatus, "UNCHANGED");

        require(user != address(0), "ZERO_ADDRESS");
        require(deadline >= block.timestamp, "EXPIRED");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        SUBSC_PERMIT_TYPEHASH,
                        user,
                        appID,
                        subscriptionStatus,
                        nonce[user]++,
                        deadline
                    )
                )
            )
        );

        address recoveredUser = ecrecover(digest, v, r, s);
        require(
            recoveredUser != address(0) &&
                (recoveredUser == user ||
                    recoveredUser == getSecondaryWalletAccount(user)),
            "INVALID_SIGN"
        );

        _subscribeToDapp(user, appID, subscriptionStatus);
    }

    function appVerification(
        bytes32 appID,
        bool verificationStatus,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) onlySuperAdmin {
        uint256 gasLeftInit = gasleft();

        require(dapps[appID].appAdmin != address(0), "INVALID DAPP ID");
        // require(appID < dappsCount, "INVALID DAPP ID");
        if (
            dapps[appID].isVerifiedDapp != verificationStatus &&
            verificationStatus
        ) {
            verifiedDappsCount++;
            dapps[appID].isVerifiedDapp = verificationStatus;
        } else if (
            dapps[appID].isVerifiedDapp != verificationStatus &&
            !verificationStatus
        ) {
            verifiedDappsCount--;
            dapps[appID].isVerifiedDapp = verificationStatus;
        }

        _updateGaslessData(gasLeftInit);
    }

    function getDappAdmin(bytes32 _dappId) public view returns (address) {
        return dapps[_dappId].appAdmin;
    }

    // -------------------- WALLET FUNCTIONS -----------------------

    function addAppAdmin(
        bytes32 appID,
        address admin, // primary address
        uint8 _role, // 0 meaning only notif, 1 meaning only add admin, 2 meaning both,
        bool isOauthUser
    )
        external
        superAdminOrDappAdminOrAddedAdmin(appID)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(dapps[appID].appAdmin != address(0), "INVALID DAPP ID");
        require(_role < 3, "INAVLID ROLE");
        if (_role == 0) {
            roleOfAddress[admin][appID].addAdminRole = false;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .addAdminRole = false;
            roleOfAddress[admin][appID].sendNotificationRole = true;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .sendNotificationRole = true;
        } else if (_role == 1) {
            roleOfAddress[admin][appID].addAdminRole = true;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .addAdminRole = true;
            roleOfAddress[admin][appID].sendNotificationRole = false;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .sendNotificationRole = false;
        } else if (_role == 2) {
            roleOfAddress[admin][appID].addAdminRole = true;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .addAdminRole = true;
            roleOfAddress[admin][appID].sendNotificationRole = true;
            roleOfAddress[getSecondaryWalletAccount(admin)][appID]
                .sendNotificationRole = true;
        }
        emit AppAdmin(appID, getDappAdmin(appID), admin, _role);
        // if (msg.sender == trustedForwarder) {
        //     gasRestrictor._updateGaslessData(_msgSender(), gasLeftInit);
        // }
        _updateGaslessData(gasLeftInit);
    }

    // primary wallet address.
    function sendAppNotification(
        bytes32 _appId,
        address walletAddress,
        string memory _message,
        string memory buttonName,
        string memory _cta,
        bool _isEncrypted,
        bool isOauthUser
    )
        external
        superAdminOrDappAdminOrSendNotifRole(_appId)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(dapps[_appId].appAdmin != address(0), "INVALID DAPP ID");
        require(dapps[_appId].credits != 0, "NOT_ENOUGH_CREDITS");
        require(isSubscribed[_appId][walletAddress] == true, "NOT_SUBSCRIBED");

        if (notificationsOf[walletAddress].length == 0) {
            // add 1 karma point
            gamification.addKarmaPoints(walletAddress, 1);

        }

        _sendAppNotification(
            _appId,
            walletAddress,
            _message,
            buttonName,
            _cta,
            _isEncrypted
        );

        _updateGaslessData(gasLeftInit);
    }

    function _sendAppNotification(
        bytes32 _appId,
        address walletAddress,
        string memory _message,
        string memory buttonName,
        string memory _cta,
        bool _isEncrypted
    ) internal {
        Notification memory notif = Notification({
            appID: _appId,
            walletAddressTo: walletAddress,
            message: _message,
            buttonName: buttonName,
            cta: _cta,
            timestamp: block.timestamp,
            isEncrypted: _isEncrypted
        });

        notificationsOf[walletAddress].push(notif);

        emit NewNotification(
            _appId,
            walletAddress,
            _message,
            buttonName,
            _cta,
            _isEncrypted,
            ++notificationsCount[_appId],
            ++noOfNotifications
        );
        --dapps[_appId].credits;
    }

    function createWallet(
        address _account,
        string calldata _encPvtKey,
        string calldata _publicKey,
        string calldata oAuthEncryptedUserId,
        bool isOauthUser,
        address referer
    ) external {
        if (!isOauthUser) {
            require(
                userWallets[_msgSender()].account == address(0),
                "ACCOUNT_ALREADY_EXISTS"
            );
            SecondaryWallet memory wallet = SecondaryWallet({
                account: _account,
                encPvtKey: _encPvtKey,
                publicKey: _publicKey
            });
            userWallets[_msgSender()] = wallet;
            getPrimaryFromSecondary[_account] = _msgSender();

            gasRestrictor.initUser(_msgSender(), _account, false);

            // add 2 karma point for _msgSender()
               gamification.addKarmaPoints(_msgSender(), 2);

            if (
                referer != address(0) &&
                getSecondaryWalletAccount(referer) != address(0)
            ) {
                 
                // add 5 karma point for _msgSender()
                // add 5 karma point for referer
                gamification.addKarmaPoints(_msgSender(), 5);
                gamification.addKarmaPoints(referer, 5);
            }
        } else {
            require(
                oAuthUserWallets[oAuthEncryptedUserId].account == address(0),
                "ACCOUNT_ALREADY_EXISTS"
            );
            require(_msgSender() == _account, "Invalid_User");
            SecondaryWallet memory wallet = SecondaryWallet({
                account: _account,
                encPvtKey: _encPvtKey,
                publicKey: _publicKey
            });
            oAuthUserWallets[oAuthEncryptedUserId] = wallet;
            // getPrimaryFromSecondary[_account] = _msgSender();

            gasRestrictor.initUser(_msgSender(), _account, true);
        }

        emit WalletCreated(
            _msgSender(),
            _account,
            isOauthUser,
            oAuthEncryptedUserId,
            ++noOfWallets
        );
    }

    function getNotificationsOf(address user)
        external
        view
        returns (Notification[] memory)
    {
        return notificationsOf[user];
    }

    function getSecondaryWalletAccount(address _account)
        public
        view
        returns (address)
    {
        return userWallets[_account].account;
    }

    // function uintToBytes32(uint256 num) public pure returns (bytes32) {
    //     return bytes32(num);
    // }

    function getDapp(bytes32 dappId) public view returns (Dapp memory) {
        return dapps[dappId];
    }

    // function upgradeCreditsByAdmin( bytes32 dappId,uint amount ) external onlySuperAdmin() {
    //     dapps[dappId].credits = defaultCredits + amount;
    // }

    function renewCredits(bytes32 dappId, bool isOauthUser)
        external
        superAdminOrDappAdminOrAddedAdmin(dappId)
        GasNotZero(_msgSender(), isOauthUser)
    {
        uint256 gasLeftInit = gasleft();

        require(dapps[dappId].appAdmin != address(0), "INVALID_DAPP");
        require(
            block.timestamp - dapps[dappId].renewalTimestamp == renewalPeriod,
            "RPNC"
        ); // RENEWAL_PERIOD_NOT_COMPLETED
        dapps[dappId].credits = defaultCredits;

        _updateGaslessData(gasLeftInit);
    }

    // function deleteWallet(address _account) external onlySuperAdmin {
    //     require(userWallets[_msgSender()].account != address(0), "NO_ACCOUNT");
    //     delete userWallets[_account];
    //     delete getPrimaryFromSecondary[_account];
    // }
    // ------------------------ TELEGRAM FUNCTIONS -----------------------------------

    function addTelegramChatID(address user, string memory chatID)
        external
        // bool isOauthUser
        isValidSender(user)
    {
        uint256 gasLeftInit = gasleft();
        require(bytes(telegramChatID[user]).length == 0, "INVALID_TG_ID"); // INVALID_TELEGRAM_ID
        telegramChatID[user] = chatID;

        _updateGaslessData(gasLeftInit);
    }

    function updateTelegramChatID(
        address user,
        string memory chatID,
        bool isOauthUser
    ) external isValidSender(user) GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();
        require(bytes(telegramChatID[user]).length != 0, "INVALID_TG_IG"); // INVALID_TELEGRAM_ID
        telegramChatID[user] = chatID;

        _updateGaslessData(gasLeftInit);
    }

    // function getTelegramChatID(address userWallet) public view returns (string memory) {
    //     return telegramChatID[userWallet];
    // }

    // function setDomainSeparator() external onlyOwner {
    //     DOMAIN_SEPARATOR = keccak256(abi.encode(
    //         EIP712_DOMAIN_TYPEHASH,
    //         keccak256(bytes("Dapps")),
    //         keccak256(bytes("1")),
    //         chainId,
    //         address(this)
    //     ));
    // }

    function _updateGaslessData(uint256 _gasLeftInit) internal {
        if(isTrustedForwarder[msg.sender]) {
            gasRestrictor._updateGaslessData(_msgSender(), _gasLeftInit);
        }
    }
}
