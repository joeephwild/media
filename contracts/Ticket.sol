//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

//OpenZeppelin's NFT Standard Contracts. We will extend functions from this in our implementation
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Ticket is  ERC1155URIStorage, ERC1155Supply {
    address payable public owner;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    
     constructor() ERC1155("") {
        owner = payable(msg.sender);
    }

    function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {}

    // Variables to store royalty split percentages
    uint256 public artistPercentage;
    uint256 public ownerPercentage;
    uint256 public sellerPercentage;

    uint256 public supply;
    bool public isSold;

    uint256 public listingPrice = 0.03 ether;

   

    struct ListedTicket {
        uint256 tokenId;
        address payable owner;
        uint256 initialSupply;
        uint256 _timeStart;
        uint256 _timeEnd;
        uint256 price;
        bool currentlyListed;
    }

    mapping(uint256 => ListedTicket) private idToListedTicket;

    modifier onlyOwner() {
        require(owner == msg.sender, "only owner call this function");
        _;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function getLatestIdToken() public view returns (ListedTicket memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedTicket[currentTokenId];
    }

    function getListedTokenId(uint256 tokenId) public view returns (ListedTicket memory) {
        return idToListedTicket[tokenId];
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }

    function createToken(
        string memory tokenURI,
        uint256 price,
        uint256 _start,
        uint256 _end,
        uint256 _supply
    ) public payable returns (uint256) {
        require(msg.value == listingPrice, "send enough ethers");
        require(price > 0, "price must be greater than 0");
        payable(owner).transfer(msg.value);
        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        _setApprovalForAll(msg.sender, owner, true);
        _mint(msg.sender, currentTokenId, _supply, "");
        _setURI(currentTokenId, tokenURI);
        createListedToken(currentTokenId, _supply, _start, _end, price);
        return currentTokenId;
    }

    function balanceOfToken(address _owner, uint256 tokenId) public view returns(uint256) {
        return balanceOf(_owner, tokenId);
    }

    function createListedToken(
        uint256 tokenId,
        uint256 _price,
        uint256 _supply,
        uint256 _start,
        uint256 _end
    ) private {
        //Make sure the sender sent enough ETH to pay for listing
        require(msg.value == listingPrice, "Hopefully sending the correct price");
        //Just sanity check
        require(_price > 0, "Make sure the price isn't negative");
        ListedTicket storage listing = idToListedTicket[tokenId];
        listing.tokenId = tokenId;
        listing.owner = payable(msg.sender);
        listing.initialSupply = _supply;
        listing._timeStart = _start;
        listing._timeEnd = _end;
        listing.price = _price;
        listing.currentlyListed = true;
        //_transfer(msg.sender, address(this), tokenId);
    }

    function getAllNfts() public view returns (ListedTicket[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedTicket[] memory tokens = new ListedTicket[](nftCount);

        uint256 currentIndex = 0;

        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for (uint256 i = 0; i < nftCount; i++) {
            uint256 currentId = i + 1;
            ListedTicket storage currentItem = idToListedTicket[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    function getMyNFTs() external view returns (ListedTicket[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedTicket[i + 1].owner == msg.sender 
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedTicket[] memory items = new ListedTicket[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedTicket[i + 1].owner == msg.sender 
            ) {
                uint currentId = i + 1;
                ListedTicket storage currentItem = idToListedTicket[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    struct Payment {
        uint256 quantity;
        uint256 total;
        string name;
        address purchaser;
    }

    mapping(address => Payment) private paymentStruct;

    function checkIfListed(uint256 tokenId) external returns (bool) {
        if (idToListedTicket[tokenId].initialSupply < 0) {
            isSold = true;
        } else {
            isSold = false;
        }
        return isSold;
    }

    function executeSale(uint256 tokenId, uint256 _quantity) external payable {
        uint price = idToListedTicket[tokenId].price * _quantity;
        require(msg.value >= price, "pls submit the asking price");
        require(_quantity < idToListedTicket[tokenId].initialSupply, "you cant purchase more");
        //specifying the percentage fee
        uint256 artistPercentageshare = 98;
        uint256 ownerPercentageshare = 2;
        //calculating the specific fee
        uint256 artistFee = msg.value * artistPercentageshare / 100;
        uint256 ownerFee = msg.value * ownerPercentageshare / 100;
        Payment storage purchase = paymentStruct[msg.sender];
        purchase.quantity = _quantity;
        purchase.purchaser = msg.sender;
        idToListedTicket[tokenId].currentlyListed = true;
        //subtracting the quantity of purchase from the initialSupply
        idToListedTicket[tokenId].initialSupply - purchase.quantity;
        address nftOwner = idToListedTicket[tokenId].owner;
        //transfering the required percentage fee to the respective wallet
        payable(nftOwner).transfer(artistFee);
        payable(owner).transfer(ownerFee);
       _itemsSold.increment();
        _setApprovalForAll(nftOwner, msg.sender, true);
        safeTransferFrom(nftOwner, msg.sender, tokenId, _quantity, "");
    }

     // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
