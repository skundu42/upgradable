// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./modified/ERC721Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./interfaces/ISubscriptionModule.sol";
import "./libraries/StringUtils.sol";
import "./GasRestrictor.sol";

contract DappsDns is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    
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

    struct Tld {
        string name;
        bool onSale;
    }

    mapping(bytes32 => Tld) public tlds; // top level domains

    // name => owner
    mapping(string => address) public domains;

    // name => dns records
    mapping(string => string[]) public records;

    // // name => tld => owner
    // mapping(string => mapping(string => address)) public domains;

    // // name => tld => dns records
    // mapping(string => mapping(string => string[])) public records;

    ISubscriptionModule public subsModule;

    GasRestrictor public gasRestrictor;

    mapping(address => bool) public hasClaimed;

    struct DnsRecord {
        uint8 recordType;
        string domain;
        string location;
        uint256 priority;
    }

    uint256 public recordCount;

    // domain => index => dns record
    mapping(string => mapping(uint256 => DnsRecord)) public dnsRecords;

    event NameRegistered(
        address indexed account, 
        string domain,
        string name,
        string tld,
        bytes32 dappId
    );

    event NftMinted(
        address indexed account,
        string domain,
        uint256 tokenId,
        string metadataUrl
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

    function _onlyOwnerOrDappAdmin(bytes32 _dappId) internal view {
        require(
            _msgSender() == owner() ||
                _msgSender() == subsModule.getDappAdmin(_dappId),
            "INVALID_SENDER"
        );
    }

    modifier onlyOwnerOrDappAdmin(bytes32 _dappId) {
        _onlyOwnerOrDappAdmin(_dappId);
        _;
    }

     modifier GasNotZero(address user, bool isOauthUser) {
        _gasNotZero(user, isOauthUser);
        _;
    }

    function __DappsDns_init(
        ISubscriptionModule _subsModule,
        GasRestrictor _gasRestrictor,
        address _trustedForwarder
    ) public initializer {
        __ERC721_init("DappsDns", "DDNS");
        __Ownable_init(_trustedForwarder);
        subsModule = _subsModule;
        gasRestrictor = _gasRestrictor;
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

    function addTld(
        bytes32 _dappId, 
        string memory _tldName,
        bool _onSale
    ) external onlyOwner {
        require(bytes(_tldName).length > 0, "INVALID_TLD");
        _tldName = StringUtils.toLower(_tldName);
        tlds[_dappId] = Tld({
            name: _tldName,
            onSale: _onSale
        });
    }

    function updateTldSaleStatus(
        bytes32 _dappId, 
        bool _onSale
    ) external onlyOwnerOrDappAdmin(_dappId) {
        Tld storage tld = tlds[_dappId];
        require(bytes(tld.name).length > 0, "INVALID_TLD");
        require(tld.onSale != _onSale, "UNCHANGED");
        tld.onSale = _onSale;
    }

    // function setRecord(
    //     address _user,
    //     string calldata _name,      // web3 domain
    //     string[] memory _record,    // list of web2 name servers
    //     bool isOauthUser
    // ) external GasNotZero(_msgSender(), isOauthUser) {
    //     uint256 gasLeftInit = gasleft();

    //     require(domains[_name] == _user, "NOT_DOMAIN_OWNER");
    //     records[_name] = _record;

    //     _updateGaslessData(gasLeftInit);
    // }

    // function getRecords(string calldata _domain) external view returns (string[] memory) {
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
        require(domains[_name] == _user, "NOT_DOMAIN_OWNER");
        require(_recordType > 0 && _recordType < 5, "INVALID_TYPE");
        require(bytes(_domain).length > 0 && bytes(_location).length > 0, "INVALID_LEN");
        if(_recordIndex == 0)
            _recordIndex = ++recordCount;

        dnsRecords[_name][_recordIndex] = DnsRecord({
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
        string memory _domain,
        uint256 _index,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domain = StringUtils.toLower(_domain);
        require(domains[_domain] == _user, "NOT_DOMAIN_OWNER");
        require(dnsRecords[_domain][_index].recordType != 0, "RECORD_NA");
        delete dnsRecords[_domain][_index];
        emit DnsRecordDeleted(_domain, _index);

        _updateGaslessData(gasLeftInit);
    }

    function getRecord(
        string memory _domain,
        uint256 _index
    ) external view returns (DnsRecord memory) {
        _domain = StringUtils.toLower(_domain);
        return dnsRecords[_domain][_index];
    } 

    // to get the price of a domain based on length
    function price(string calldata name) public pure returns (uint256) {
        uint256 len = StringUtils.strlen(name);
        require(len > 0, "INVALID_LENGTH");

        if (len == 1) {
            return 10**23;      // 100_000 Matic
        } else if (len == 2) {
            return 10**21;      // 10_000 Matic
        } else if (len == 3) {
            return 10**21;      // 1000 Matic
        } else if (len == 4) {
            return 10**20;      // 100 Matic
        } else if (len == 5) {
            return 10**19;      // 10 Matic
        } else {
            return 10**18;      // 1 Matic
        }
    }

    function claimDomain(
        address _user,
        bytes32 _dappId,
        string calldata _name,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        require(!hasClaimed[_user], "CLAIMED!");
        _claimDomain(_user, _dappId, _name);

        _updateGaslessData(gasLeftInit);
    }

    function _claimDomain(
        address _user,
        bytes32 _dappId,
        string memory _name
    ) internal {
        Tld memory tld = tlds[_dappId];
        require(bytes(tld.name).length > 0, "TLD_NA");   // TLD_NOT_AVAILABLE
        require(tld.onSale, "NOT_ON_SALE");

        // length >= 4, [A-Z a-z 0-9]
        uint256 len = StringUtils.strlen(_name);
        require(len >= 4, "MIN_4_CHARS");

        bool success = StringUtils.checkAlphaNumeric(_name);
        require(success, "ONLY_ALPHANUMERIC");

        _name = StringUtils.toLower(_name);
        string memory domain = _concatenate(_name, tld.name);
        require(domains[domain] == address(0), "DOMAIN_UNAVAILABLE");

        hasClaimed[_user] = true;
        domains[domain] = _user;
        emit NameRegistered(_user, domain, _name, tld.name, _dappId);
    }

    function register(
        bytes32 _dappId,
        string calldata _name
    ) external payable onlyOwner {
        string memory tld = tlds[_dappId].name;
        require(bytes(tld).length > 0, "INVALID_TLD");
        // length >= 4, [A-Z a-z 0-9 /]

        string memory domain = _concatenate(_name, tld);
        require(domains[domain] == address(0), "DOMAIN_UNAVAILABLE");

        // uint256 _price = price(_name);
        // require(msg.value >= _price, "Not enough Matic paid");

        domains[domain] = _msgSender();
        emit NameRegistered(_msgSender(), domain, _name, tld, _dappId);
    }

    function safeMint(
        address _user,
        string memory _domainName,
        string calldata _url,
        bool isOauthUser
    ) external GasNotZero(_msgSender(), isOauthUser) {
        uint256 gasLeftInit = gasleft();

        _domainName = StringUtils.toLower(_domainName);
        require(domains[_domainName] == _user, "NOT_DOMAIN_OWNER");

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

        _updateGaslessData(gasLeftInit);
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
        require(domains[_domain] == _from, "FROM_NOT_OWNER");
        uint256 tokenId = tokenIdByDomain[_domain];
        require(tokenId != 0, "NOT_MINTED");

        safeTransferFrom(_from, _to, tokenId);
        domains[_domain] = _to;
        _updateGaslessData(gasLeftInit);
    }

    function _concatenate(
        string memory _name,
        string memory _tld
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(_name, _tld));
    }

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

}
