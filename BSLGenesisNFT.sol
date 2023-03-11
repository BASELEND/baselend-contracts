pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// BSLGenesisNFT
contract BSLGenesisNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable stableCoinAddress;

    uint256 public immutable targetStableCoinRaise;

    uint256 public immutable maxStableCoinPurchase;
    uint256 public immutable minStableCoinPurchase;

    uint256 public stableCoinRaiseRemaining;

    uint256 public startTime;
    uint256 public endTime;

    string public imageURL;

    mapping(address => uint256) public userNFTTokenIdMap;
    mapping(address => uint256) public userStableCoinTally;

    uint public constant BSLPerUSDCE30 = 3333333333333333333333333333333;

    uint public immutable oneStableCoin;

    address public immutable treasuryAddress;

    event BSLPurchased(address sender, uint256 stableCoinSpent);
    event CreateBSLGenesisNFT(uint indexed id);
    event ImageURLChanged(string oldImageURL, string newImageURL);
    event StartTimeChanged(uint256 newStartTime, uint256 newEndTime);

    constructor(uint256 _startTime, uint256 _endTime, address _stableCoinAddress, address _treasuryAddress, string memory name1, string memory name2) ERC721(name1, name2) {
        require(block.timestamp < _startTime, "cannot set start block in the past!");
        require(_startTime < _endTime, "end time must be after start time!");
        require(_stableCoinAddress != address(0), "_treasuryAddress cannot be the zero address");
        require(_treasuryAddress != address(0), "_treasuryAddress cannot be the zero address");
    
        startTime = _startTime;
        endTime = _endTime;

        stableCoinAddress = _stableCoinAddress;

        oneStableCoin = 10 ** ERC20(stableCoinAddress).decimals();

        targetStableCoinRaise = 6e6 * oneStableCoin;

        maxStableCoinPurchase = 100 * 1e3 * oneStableCoin;
        minStableCoinPurchase = 100 * oneStableCoin;


        stableCoinRaiseRemaining = targetStableCoinRaise;

        treasuryAddress = _treasuryAddress;
    }

    function buyBSL(uint256 stableCoinToSpend) external nonReentrant {
        require(block.timestamp >= startTime, "presale hasn't started yet!");
        require(block.timestamp < endTime, "presale has ended!!");
        require(stableCoinToSpend > 0, "not enough stable coin provided");
        require(stableCoinRaiseRemaining > 0, "presale has ended!!");
        require(userStableCoinTally[msg.sender] < maxStableCoinPurchase, "user has already purchased too much BSL");
        require(userStableCoinTally[msg.sender] + stableCoinToSpend >= minStableCoinPurchase, "your buy of BSL is too small!");

        if (userStableCoinTally[msg.sender] + stableCoinToSpend > maxStableCoinPurchase)
            stableCoinToSpend = maxStableCoinPurchase - userStableCoinTally[msg.sender];

        // if we dont have enough left, give them the rest.
        if (stableCoinRaiseRemaining < stableCoinToSpend)
            stableCoinToSpend = stableCoinRaiseRemaining;

        require(stableCoinToSpend > 0, "user cannot purchase 0 BSL");

        // shouldn't be possible to fail these asserts.
        assert(stableCoinToSpend <= stableCoinRaiseRemaining);

        stableCoinRaiseRemaining = stableCoinRaiseRemaining - stableCoinToSpend;

        if (userStableCoinTally[msg.sender] == 0) {
            uint tokenId = totalSupply();

            userNFTTokenIdMap[msg.sender] = tokenId;

            _mint(msg.sender, tokenId);

            emit CreateBSLGenesisNFT(tokenId);
        }
        
        userStableCoinTally[msg.sender] = userStableCoinTally[msg.sender] + stableCoinToSpend;

        if (stableCoinToSpend > 0)
            ERC20(stableCoinAddress).safeTransferFrom(msg.sender, treasuryAddress, stableCoinToSpend);

        emit BSLPurchased(msg.sender, stableCoinToSpend);
    }

    /**
     * generates an attribute for the attributes array in the ERC721 metadata standard
     * @param traitType the trait type to reference as the metadata key
     * @param value the token's trait associated with the key
     * @return a JSON dictionary for the single attribute
     */
    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
        '{"trait_type":"',
        traitType,
        '","value":"',
        value,
        '"}'
        ));
    }

    /**
     * generates an array composed of all the individual traits and values
     * @param tokenId the ID of the token to compose the metadata for
     * @return a JSON array of all of the attributes for given token ID
     */
    function compileAttributes(uint256 tokenId) public view returns (string memory) {
        string memory traits;
        address owner = ownerOf(tokenId);

        // BSL will be 18 decimal
        uint BSLAllocaiton = (1e18 * userStableCoinTally[owner] * BSLPerUSDCE30 / 1e30) / oneStableCoin;

        traits = string(abi.encodePacked(
            attributeForTypeAndValue("Genesis Minter", Strings.toHexString(uint256(uint160(owner)), 20)),',',
            attributeForTypeAndValue("BSL Allocation", Strings.toString(BSLAllocaiton)),',',
            attributeForTypeAndValue("USD Contribution", Strings.toString(userStableCoinTally[owner]))
        ));
        return string(abi.encodePacked(
        '[',
        traits,
        ']'
        ));
    }

    /**
     * generates a base64 encoded metadata response without referencing off-chain content
     * @param tokenId the ID of the token to generate the metadata for
     * @return a base64 encoded JSON dictionary of the token's metadata and SVG
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory metadata = string(abi.encodePacked(
        '{"name": "',
        'BaseLend Genesis NFT #',
        Strings.toString(tokenId),
        '", "description": "',
        'BaseLend Genesis NFT, get your piece of BaseLend. $BSL. BaseLend, an open source and non-custodial lending market on @BuildOnBase. Lend LSD\'s, FX, stablecoins, NFT\'s, or create your own isolated markets. #BASE $BSL"',
        ', "image": "',
        imageURL,
        '", "attributes":',
        compileAttributes(tokenId),
        "}"
        ));

        return string(abi.encodePacked(
        "data:application/json;base64,",
        Base64.encode(bytes(metadata))
        ));
    }

    function setImageURL(string memory newImageURL) external onlyOwner {
        emit ImageURLChanged(imageURL, newImageURL);

        imageURL = newImageURL;
    }

    function walletOfOwner(address _owner, uint startIndex, uint count) external view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);

        uint[] memory tokensId = new uint[](tokenCount);
        for (uint i = startIndex; i < tokenCount && i - startIndex < count; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function setStartTime(uint _newStartTime, uint _newEndTime) external onlyOwner {
        require(block.timestamp < startTime, "Presale has already started!");
        require(block.timestamp < _newStartTime, "cannot set start block in the past!");
        require(_newStartTime < _newEndTime, "end time must be after start time!");
        require(startTime < _newStartTime, "Can't make presale sooner, only later!");

        startTime = _newStartTime;
        endTime = _newEndTime;

        emit StartTimeChanged(startTime, endTime);
    }
}