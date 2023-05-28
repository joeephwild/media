//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MusicNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; 
    uint256 public tokenCounter;
    address payable public owner;
    address public artist;
    uint256 public royaltyFee;

    struct MusicItem {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }
    //MusicItem[] public musicItems;
    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => MusicItem) private musicItems;

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
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed
    );
    
    address public conAddress = address(this);

    //event Minted(address indexed minter, uint256 nftID, string uri);

    constructor() ERC721("musicNFT", "MNFTART") {
        tokenCounter = 0;
        //listingCounter = 0;
        owner = payable(msg.sender);
        // console.log(address(this));
        console.log(owner.balance);
    }


    // setup royality fee that is going to be paid to artist the creator
    function setupRoyaltyFee(uint256 _royaltyFee) external {
        royaltyFee = _royaltyFee; // 0.04 percent
    }

    // Mint music as creator
    function mintMusic(
        uint256 _price,
        string memory tokenURI) 
        public returns (uint256) {        
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
        musicItems[newTokenId] = MusicItem(
            newTokenId, 
            payable(address(this)),
            payable(msg.sender), 
            _price,
            true
        );
        // musicItems.push(
        //     MusicItem(
        //     newTokenId, 
        //     payable(address(this)),
        //     payable(msg.sender), 
        //     _price, 
        //     true));
        emit Minted(
            newTokenId,
            payable(address(this)),
            payable(msg.sender), 
            _price,
            true);
        // tokenaddress[msg.sender].push(newTokenId);
        return newTokenId;
    }

    /* Updates the royalty fee of the contract */
    function updateRoyaltyFee(uint256 _royaltyFee) external {
        royaltyFee = _royaltyFee;
    }

    /* Creates the sale of a music nft listed on the marketplace */
    /* Transfers ownership of the nft, as well as funds between parties */
    function buyToken(uint256 _tokenId) external payable {
        uint256 price = musicItems[_tokenId].price;
        address seller = musicItems[_tokenId].seller;
        require(
            msg.value == price,
            "Please send the asking price in order to complete the purchase"
        );
        musicItems[_tokenId].seller = payable(address(0));
        //_transfer(seller, msg.sender, _tokenId);

        //Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, _tokenId);
        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), _tokenId);

        royaltyFee = royaltyFee * price; // 0.04 or 4% percent of the selling price goes to the contract owners
        payable(owner).transfer(royaltyFee);
        payable(seller).transfer(msg.value-royaltyFee);
        
        emit MarketItemBought(_tokenId, seller, msg.sender, price);
        console.log(owner.balance);
    }

    /* Allows someone to resell their music nft */
    function resellToken(uint256 _tokenId, uint256 _price) external payable {
        //require(msg.value == royaltyFee, "Must pay royalty");
        require(_price > 0, "Price must be greater than zero");
        musicItems[_tokenId].price = _price;
        musicItems[_tokenId].seller = payable(msg.sender);
        
        _transfer(msg.sender, address(this), _tokenId);
        emit MarketItemRelisted(_tokenId, msg.sender, _price);
    }

    
    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (MusicItem[] memory) {
        uint nftCount = _tokenIds.current();
        MusicItem[] memory tokens = new MusicItem[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will 
        //filter out currentlyListed == false over here
        for(uint i=0;i<nftCount;i++)
        {
            currentId = i + 1;
            MusicItem storage currentItem = musicItems[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }
    
    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (MusicItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            if(musicItems[i+1].owner == msg.sender || musicItems[i+1].seller == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        MusicItem[] memory items = new MusicItem[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            if(musicItems[i+1].owner == msg.sender || musicItems[i+1].seller == msg.sender) {
                currentId = i+1;
                MusicItem storage currentItem = musicItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    

    /* Fetches all the tokens currently listed for sale */
    // function getAllUnsoldTokens() external view returns (MusicItem[] memory) {
    //     uint256 unsoldCount = balanceOf(address(this));
    //     MusicItem[] memory tokens = new MusicItem[](unsoldCount);
    //     uint256 currentIndex;
    //     for (uint256 i = 0; i < musicItems.length; i++) {
    //         if (musicItems[i].seller != address(0)) {
    //             tokens[currentIndex] = musicItems[i];
    //             currentIndex++;
    //         }
    //     }
    //     return (tokens);
    // }

    /* Fetches all the tokens owned by the user */
    // function getMyTokens() external view returns (MusicItem[] memory) {
    //     uint256 myTokenCount = balanceOf(msg.sender);
    //     MusicItem[] memory tokens = new MusicItem[](myTokenCount);
    //     uint256 currentIndex;
    //     for (uint256 i = 0; i < musicItems.length; i++) {
    //         if (ownerOf(i) == msg.sender) {
    //             tokens[currentIndex] = musicItems[i];
    //             currentIndex++;
    //         }
    //     }
    //     return (tokens);
    // }

    /* Internal function that gets the baseURI initialized in the constructor */
    // function _baseURI() internal view virtual override returns (string memory) {
    //     return baseURI;
    // }
}
