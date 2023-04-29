// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./modified/ERC721EnumerableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/ISubscriptionModule.sol";
import "./libraries/StringUtils.sol";
import "./GasRestrictor.sol";
// import "hardhat/console.sol";

contract DappsDnsNewEnumerable is Initializable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    struct NftDetails {
        string name;
        string url;
    }

    // tokenId => Nft
    mapping(uint256 => NftDetails) public nfts;

    // domain => tokenId
    mapping(string => uint256) public tokenIdByDomain;

    // struct Tld {
    //     string name;
    //     bool onSale;
    // }

    // mapping(bytes32 => Tld) public tlds; // top level domains
    mapping(string => bool) public isTldCreated;
    mapping(string => bool) public isTldOnSale;

    // type(1: btc, 2: polka, 3: tezos) => isAllowed
    mapping(uint256 => bool) public isAllowedAccount;

    struct Domain {
        // bytes32 dappId;
        string tld;
        address owner;
        uint256 expiryTimestamp;
        bool isForLifetime;
    }

    // name => owner
    mapping(string => Domain) public domains;

    // domain => type (1: btc, 2: polka, 3: tezos) => address
    mapping(string => mapping(uint256 => string)) public otherAccounts;

    // 1 credit = 1 wei
    mapping(address => uint256) public credits;

    uint256 public gracePeriod;

    // struct Record {
    //     string domain;
    //     string location;
    // }

    // struct MxRecord {
    //     string domain;
    //     string location;
    //     string priority;
    // }

    // struct DnsRecord {
    //     Record aRecord;
    //     Record cName;
    //     MxRecord mxRecord;
    //     Record txt;
    // }

    // // domain => dns record
    // mapping(string => DnsRecord) public records;

    // enum RecordType {
    //     A_RECORD,
    //     CNAME,
    //     MX,
    //     TXT
    // }

    struct DnsRecord {
        uint8 recordType;
        string domain;
        string location;
        uint256 priority;
    }

    uint256 public recordCount;

    // domain => index => dns record
    mapping(string => mapping(uint256 => DnsRecord)) public records;

    ISubscriptionModule public subsModule;

    GasRestrictor public gasRestrictor;

    uint256 public domainsCount;

    uint256 public annualPrice;

    uint256 public lifetimePrice;

    uint256 public tldCount;

    event TldUpdated(
        string tldName,
        bool onSale,
        uint256 count
    );

    event NameRegistered(
        address indexed account, 
        string domain,
        string name,
        string tld,
        bool isForLifetime,
        string referrerDomain,
        uint256 count
    );

    event NftMinted(
        address indexed account,
        string domain,
        uint256 tokenId,
        string metadataUrl
    );

    event UpdatedAllowedAccountType(
        uint256 accountType,
        bool status
    );
    
    event UpdatedOtherAccounts(
        address indexed user,
        string domainName,
        uint256 otherAccountType,
        string otherAccount
    );

    event DnsRecordUpdated(
        address indexed user,
        string name,               // web3 domain
        uint256 recordIndex,
        uint8 recordType,
        string domain,
        string location,
        uint256 priority
    );

    event DnsRecordDeleted(
        string domain,
        uint256 index
    );

     modifier GasNotZero(address user, bool isOauthUser) {
        _gasNotZero(user, isOauthUser);
        _;
    }

    function __DappsDns_init(
        address _subsModule,
        address _gasRestrictor,
        address _trustedForwarder,
        uint256 _annualPrice,
        uint256 _lifetimePrice
    ) public initializer {
        __ERC721_init("DappsDns", "DDNS");
        __Ownable_init(_trustedForwarder);
        subsModule = ISubscriptionModule(_subsModule);
        gasRestrictor = GasRestrictor(_gasRestrictor);
        gracePeriod = 30 days;
        annualPrice = _annualPrice;
        lifetimePrice = _lifetimePrice;
    }

    function updateAnnualPrice(uint256 _annualPrice) external onlyOwner {
        annualPrice = _annualPrice;
    }

    function updateLifetimePrice(uint256 _lifetimePrice) external onlyOwner {
        lifetimePrice = _lifetimePrice;
    }

    function updateGasRestrictor(
        GasRestrictor _gasRestrictor
    ) external onlyOwner {
        require(address(_gasRestrictor) != address(0), "ZERO_ADDRESS");
        gasRestrictor = _gasRestrictor;
    }

    function updateSubscriptionModule(
        ISubscriptionModule _subsModule
    ) external onlyOwner {
        require(address(_subsModule) != address(0), "ZERO_ADDRESS");
        subsModule = _subsModule;
    }

    function _gasNotZero(address user, bool isOauthUser) internal view {
        if (isTrustedForwarder[msg.sender]) {
            if (!isOauthUser) {
                if (
                    subsModule.getPrimaryFromSecondary(user) == address(0)
                ) {} else {
                    (, , uint256 u) = gasRestrictor.gaslessData(
                        subsModule.getPrimaryFromSecondary(user)
                    );
                    require(u != 0, "0_GASBALANCE");
                }
            } else {
                (, , uint256 u) = gasRestrictor.gaslessData(user);
                require(u != 0, "0_GASBALANCE");
            }
        }
    }

    function getDomainData(
        string memory _domain
    ) external view returns (Domain memory) {
        _domain = StringUtils.toLower(_domain);
        return domains[_domain];
    }

    function addTld( 
        string memory _tldName,
        bool _onSale
    ) external onlyOwner {
        require(bytes(_tldName).length > 0, "INVALID_TLD");
        _tldName = StringUtils.toLower(_tldName);
        require(!isTldCreated[_tldName], "TLD_EXISTS");
        isTldCreated[_tldName] = true;
        isTldOnSale[_tldName] = _onSale;
        emit TldUpdated(_tldName, _onSale, ++tldCount);
    }

    function updateTldSaleStatus(
        string memory _tld,
        bool _onSale
    ) external onlyOwner {
        require(bytes(_tld).length > 0, "INVALID_TLD");
        _tld = StringUtils.toLower(_tld);
        require(isTldOnSale[_tld] != _onSale, "UNCHANGED");
        isTldOnSale[_tld] = _onSale;
        emit TldUpdated(_tld, _onSale, tldCount);
    }

    // function setRecord(
    //     address _user,
    //     string calldata _name,      // web3 domain
    //     uint _recordType,
    //     string calldata _domain,
    //     string calldata _location,
    //     string memory _priority,
    //     bool isOauthUser
    // ) external GasNotZero(_msgSender(), isOauthUser) {
    //     uint256 gasLeftInit = gasleft();

    //     require(domains[_name].owner == _user, "NOT_DOMAIN_OWNER");

    //     if(_recordType == 1) {
    //         records[_name].aRecord = Record({
    //             domain: _domain,
    //             location: _location
    //         });
    //     }
    //     else if(_recordType == 2) {
    //         records[_name].cName = Record({
    //             domain: _domain,
    //             location: _location
    //         });
    //     }
    //     else if(_recordType == 3) {
    //         records[_name].mxRecord = MxRecord({
    //             domain: _domain,
    //             location: _location,
    //             priority: _priority
    //         });
    //     }
    //     else if(_recordType == 4) {
    //         records[_name].txt = Record({
    //             domain: _domain,
    //             location: _location
    //         });
    //     }

    //     _updateGaslessData(gasLeftInit);
    // }

    // function getRecords(string calldata _domain) external view returns (DnsRecord memory) {
    //     return records[_domain];
    // } 

    function setRecord(
        address _user,
        string memory _name,      // web3 domain
        uint256 _recordIndex,       // 0 if new record is to be added, otherwise the index to be updated
        uint8 _recordType,
        string calldata _domain,
        string calldata _location,
        uint256 _priority,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _name = StringUtils.toLower(_name);
        require(domains[_name].owner == _user, "NOT_DOMAIN_OWNER");
        require(_recordType > 0 && _recordType < 5, "INVALID_TYPE");
        require(bytes(_domain).length > 0 && bytes(_location).length > 0, "INVALID_LEN");
        if(_recordIndex == 0)
            _recordIndex = ++recordCount;

        records[_name][_recordIndex] = DnsRecord({
            recordType: _recordType,
            domain: _domain,
            location: _location,
            priority: _priority
        });

        emit DnsRecordUpdated(_user, _name, _recordIndex, _recordType, _domain, _location, _priority);

        _updateGaslessData(gasLeftInit);
    }

    function deleteRecord(
        address _user,
        string memory _domain,    // web3 domain
        uint256 _index,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domain = StringUtils.toLower(_domain);
        require(domains[_domain].owner == _user, "NOT_DOMAIN_OWNER");
        require(records[_domain][_index].recordType != 0, "RECORD_NA");
        delete records[_domain][_index];
        emit DnsRecordDeleted(_domain, _index);

        _updateGaslessData(gasLeftInit);
    }

    function getRecord(
        string memory _domain,
        uint256 _index
    ) external view returns (DnsRecord memory) {
        _domain = StringUtils.toLower(_domain);
        return records[_domain][_index];
    } 

    function addCredits(
        address _user,
        uint256 _credits
    ) external onlyOwner {
        require(_credits > 0, "ZERO_VALUE");
        credits[_user] += _credits;
    }

    function registerDomain(
        address _user,
        string memory _tld,
        string calldata _name,
        bool _isForLifetime,
        string calldata _referrer,
        bool _isOauthUser
    ) external payable GasNotZero(_msgSender(), _isOauthUser) {
        uint256 gasLeftInit = gasleft();
        // console.log("msg.value1: ", msg.value);
        
        _registerDomain(_user, _tld, _name, _isForLifetime, _referrer);

        _updateGaslessData(gasLeftInit);
    }

    function _registerDomain(
        address _user,
        string memory _tld,
        string memory _name,
        bool _isForLifetime,
        string calldata _referrer
    ) internal {
        // console.log("msg.value2: ", msg.value);
        require(bytes(_tld).length > 0, "TLD_NA");   // TLD_NOT_AVAILABLE

        _tld = StringUtils.toLower(_tld);
        require(isTldOnSale[_tld], "NOT_ON_SALE");
        
        // length >= 3, [A-Z a-z 0-9]
        require(StringUtils.strlen(_name) >= 3, "MIN_3_CHARS");
        require(StringUtils.checkAlphaNumeric(_name), "ONLY_ALPHANUMERIC");

        _name = StringUtils.toLower(_name);
        string memory domain = StringUtils.concatenate(_name, _tld);
        Domain memory domainData = domains[domain];
        
        // should not be already registered for lifetime
        require(!domainData.isForLifetime, "ALREADY_REG_FOR_LT");

        // when domain is locked for next 30 days after expiry
        if(block.timestamp >= domainData.expiryTimestamp && block.timestamp < domainData.expiryTimestamp + gracePeriod)
            revert("LOCKED_DOMAIN");
        
        // when 1 year is not over since the domain is registered
        if(block.timestamp < domainData.expiryTimestamp && domainData.owner != address(0))
            revert("DOMAIN_UNAVAILABLE");


        if(_isForLifetime) {
            uint256 creditValue = _updateCreditValue(_user, lifetimePrice);
            _rewardReferrer(_referrer, lifetimePrice);
            domains[domain] = Domain({
                tld: _tld,
                owner: _user,
                expiryTimestamp: type(uint256).max,
                isForLifetime: true
            });
            
            _sendBackNativeToken(_user, lifetimePrice, creditValue);
        }
        else {
            uint256 creditValue = _updateCreditValue(_user, annualPrice);
            _rewardReferrer(_referrer, annualPrice);
            domains[domain] = Domain({
                tld: _tld,
                owner: _user,
                expiryTimestamp: block.timestamp + 365 days,    // register for 1 year
                isForLifetime: false
            });

            _sendBackNativeToken(_user, annualPrice, creditValue);
        }

        // console.log("tx done");
        emit NameRegistered(_user, domain, _name, _tld, _isForLifetime, _referrer, ++domainsCount);
    }

    function _updateCreditValue(
        address _user,
        uint256 _domainPrice
    ) internal returns (uint256) {
        // 80% of payment can be done using credit points 
        // Case I (lifetime) : 25 ether * 80 / 100 = 20 ether
        // Case II (one year) : 10 ether * 80 / 100 = 8 ether
        uint256 allowedCredits =  _domainPrice * 4 / 5;
        // console.log("allowedCredits: ", allowedCredits);
        uint256 creditValue;
        if(credits[_user] >= allowedCredits)
            creditValue = allowedCredits;
        else
            creditValue = credits[_user];

        credits[_user] -= creditValue;
        require((msg.value + creditValue) >= _domainPrice, "LESS_AMOUNT");

        // console.log("creditValue: ", creditValue);
        return creditValue;
    }

    function _rewardReferrer(
        string calldata _referrer,
        uint256 _domainPrice
    ) internal {
        if(bytes(_referrer).length > 0) {
            require(domains[_referrer].owner != address(0), "INVALID_REF");
            // console.log("ref done");

            (bool success, ) = domains[_referrer].owner.call{value: _domainPrice / 4}("");
            require(success, "SEND_BACK_FAILED");
            // console.log("ref done2: ", success);
        }
    }

    // send back remaining native tokens
    function _sendBackNativeToken(
        address _user,
        uint256 _domainPrice,
        uint256 _creditValue
    ) internal {
        if(msg.value + _creditValue > _domainPrice) {
            // console.log("prefix: ", (msg.value + _creditValue));
            // console.log("suffix: ", _domainPrice);
            (bool success, ) = _user.call{value: ((msg.value + _creditValue) - _domainPrice)}("");
            require(success, "SEND_BACK_FAILED");
        }
    }

    function mintDomain(
        address _user,
        string memory _domainName,
        string calldata _url,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domainName = StringUtils.toLower(_domainName);
        require(tokenIdByDomain[_domainName] == 0, "ALREADY_MINTED");
        require(domains[_domainName].owner == _user, "NOT_DOMAIN_OWNER");

        _mintDomain(_user, _domainName, _url);

        _updateGaslessData(gasLeftInit);
    }

    function _mintDomain(
        address _user,
        string memory _domainName,
        string calldata _url
    ) internal {
        _tokenIdCounter.increment();    // to start tokenId from 1
        uint256 tokenId = _tokenIdCounter.current();

        NftDetails memory nft = NftDetails({
            name: _domainName,
            url: _url
        });
        nfts[tokenId] = nft;
        tokenIdByDomain[_domainName] = tokenId;
        
        // _tokenIdCounter.increment();
        _safeMint(_user, tokenId);
        emit NftMinted(_user, _domainName, tokenId, _url);
    }

    function transferFrom(
        string memory _domain,
        address _from,
        address _to,
        // uint256 _tokenId,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domain = StringUtils.toLower(_domain);
        require(domains[_domain].owner == _from, "FROM_NOT_OWNER");
        uint256 tokenId = tokenIdByDomain[_domain];
        require(tokenId != 0, "NOT_MINTED");

        safeTransferFrom(_from, _to, tokenId);
        domains[_domain].owner = _to;
        
        _updateGaslessData(gasLeftInit);
    }

    function updateOtherAccountTypes(
        uint256 _accountType,
        bool _status
    ) external onlyOwner {
        require(isAllowedAccount[_accountType] != _status, "UNCHANGED");
        isAllowedAccount[_accountType] = _status;
        emit UpdatedAllowedAccountType(_accountType, _status);
    }

    function updateOtherAccounts(
        address _user,
        string memory _domainName,
        uint256 _otherAccountType,
        string calldata _otherAccount,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domainName = StringUtils.toLower(_domainName);
        require(domains[_domainName].owner == _user, "NOT_DOMAIN_OWNER");
        require(isAllowedAccount[_otherAccountType], "ACC_TYPE_NOT_SUPPORTED");

        otherAccounts[_domainName][_otherAccountType] = _otherAccount;

        emit UpdatedOtherAccounts(_user, _domainName, _otherAccountType, _otherAccount);
        _updateGaslessData(gasLeftInit);
    }

    // function _concatenate(
    //     string memory _name,
    //     string memory _tld
    // ) internal pure returns (string memory) {
    //     return string(abi.encodePacked(_name, _tld));
    // }

    function _updateGaslessData(uint256 _gasLeftInit) internal {
        if (isTrustedForwarder[msg.sender]) {
            gasRestrictor._updateGaslessData(_msgSender(), _gasLeftInit);
        }
    }

    function _msgSender() internal view override(ContextUpgradeable, OwnableUpgradeable) returns (address) {
        return OwnableUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    function getBackNativeTokens(
        address payable _account
    ) external onlyOwner {
        (bool success, ) = _account.call{value: address(this).balance}("");
        require(success, "TRANSFER_FAILED");
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return nfts[tokenId].url;
    }

    receive() external payable {}

}