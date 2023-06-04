//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface SubscriptionContract {
   function isSubscriber(address _address) external view returns(bool);
}

contract Podcast is ERC721URIStorage , Ownable  {
    address subscriptioncontract = 0x93f8dddd876c7dBE3323723500e83E202A7C96CC;
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; 
    uint256 public tokenCounter;
    address payable public contractowner;
    address public artist;
    uint256 public royaltyFee;

    struct PodcastItem {
        uint256 tokenId;
        address payable contractowner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }
    //PodcastItem[] public PodcastItems;
    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => PodcastItem) private PodcastItems;

    event MarketItemBought(
        uint256 indexed tokenId,
        address indexed seller,
        address buyer,
        uint256 price
    );
    event MarketItemRelisted(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    //the event emitted when a token is successfully listed
    event Minted (
        uint256 indexed tokenId,
        address contractowner,
        address seller,
        uint256 price,
        bool currentlyListed
    );
    
    address public conAddress = address(this);

    //event Minted(address indexed minter, uint256 nftID, string uri);

    constructor() ERC721("PodcastNFT", "MNFTART") {
        tokenCounter = 0;
        contractowner = payable(msg.sender);
    }

    // setup royality fee that is going to be paid to artist the creator
    function setupRoyaltyFee(uint256 _royaltyFee) external onlyOwner  {
        royaltyFee = _royaltyFee; // 0.04 percent
    }

    // Mint Podcast as creator
    function mintPodcast(
        uint256 _price,
        string memory tokenURI) 
        public returns (uint256) { 
        require(SubscriptionContract(subscriptioncontract).isSubscriber(msg.sender), "You either need to subscribe first or renew your subscription.");        
        // require(
        //     _price + royaltyFedd<= msg.value,
        //     "Deployer must pay royalty fee for each token listed on the marketplace"
        // );        
        tokenCounter++;
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        _transfer(msg.sender, address(this), newTokenId);
        PodcastItems[newTokenId] = PodcastItem(
            newTokenId, 
            payable(address(this)),
            payable(msg.sender), 
            _price,
            true
        );

        emit Minted(
            newTokenId,
            payable(address(this)),
            payable(msg.sender), 
            _price,
            true);
        return newTokenId;
    }

    /* Updates the royalty fee of the contract */
    function updateRoyaltyFee(uint256 _royaltyFee) external onlyOwner {
        royaltyFee = _royaltyFee;
    }

    /* Creates the sale of a Podcast nft listed on the marketplace */
    /* Transfers ownership of the nft, as well as funds between parties */
    function buyPodcastToken(uint256 _tokenId) external payable {
        uint256 price = PodcastItems[_tokenId].price;
        address seller = PodcastItems[_tokenId].seller;
        require(
            msg.value == price,
            "Please send the asking price in order to complete the purchase"
        );
        PodcastItems[_tokenId].seller = payable(address(0));
        //_transfer(seller, msg.sender, _tokenId);

        //Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, _tokenId);
        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), _tokenId);

        //royaltyFee = price - royaltyFee * price; // 0.04 or 4% percent of the selling price goes to the contract contractowners
        payable(contractowner).transfer(royaltyFee);
        payable(seller).transfer(msg.value-royaltyFee);

        emit MarketItemBought(_tokenId, seller, msg.sender, price);
    }

    /* Allows someone to resell their Podcast nft */
    function resellPodcastToken(uint256 _tokenId, uint256 _price) external payable {
        //require(msg.value == royaltyFee, "Must pay royalty");
        require(SubscriptionContract(subscriptioncontract).isSubscriber(msg.sender), "You either need to subscribe first or renew your subscription.");
        require(_price > 0, "Price must be greater than zero");
        PodcastItems[_tokenId].price = _price;
        PodcastItems[_tokenId].seller = payable(msg.sender);
        
        _transfer(msg.sender, address(this), _tokenId);
        emit MarketItemRelisted(_tokenId, msg.sender, _price);
    }

    
    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (PodcastItem[] memory) {
        uint nftCount = _tokenIds.current();
        PodcastItem[] memory tokens = new PodcastItem[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will 
        //filter out currentlyListed == false over here
        for(uint i=0;i<nftCount;i++)
        {
            currentId = i + 1;
            PodcastItem storage currentItem = PodcastItems[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }
    
    //Returns all the NFTs that the current user is contractowner or seller in
    function getMyNFTs() public view returns (PodcastItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            if(PodcastItems[i+1].contractowner == msg.sender || PodcastItems[i+1].seller == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        PodcastItem[] memory items = new PodcastItem[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            if(PodcastItems[i+1].contractowner == msg.sender || PodcastItems[i+1].seller == msg.sender) {
                currentId = i+1;
                PodcastItem storage currentItem = PodcastItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

}
