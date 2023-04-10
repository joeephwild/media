// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "hardhat/console.sol";

contract NFTAuction is ERC721URIStorage, ReentrancyGuard {

    uint256 public tokenCounter;
    uint256 public listingCounter;

    uint8 public constant STATUS_OPEN = 1;
    uint8 public constant STATUS_DONE = 2;

    uint256 public minAuctionIncrement = 10; // 10 percent
    uint256 public commitmentPrice = 200 wei;

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price; // display price
        uint256 netPrice; // actual price
        uint256 startAt;
        uint256 endAt; 
        uint8 status;
    }

    event Minted(address indexed minter, uint256 nftID, string uri);
    event AuctionCreated(uint256 listingId, address indexed seller, uint256 price, uint256 tokenId, uint256 startAt, uint256 endAt);
    event BidCreated(uint256 listingId, address indexed bidder, uint256 bid);
    event AuctionCompleted(uint256 listingId, address indexed seller, address indexed bidder, uint256 bid);
    event WithdrawBid(uint256 listingId, address indexed bidder, uint256 bid);

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(uint256 => address) public highestBidder;
     
    constructor() ERC721("piggyNFT", "PNFT") {
        tokenCounter = 0;
        listingCounter = 0;
    }

    struct Bidders {
        uint biddingPrice;
        uint commitmentPrice;
        bool exists;
    }

    //mapping(address => Bidder) public bidders;
    mapping(uint256 => mapping(address => Bidders)) public bidders;

    function isBidder(uint listingId, address bidder) public view returns(bool isIndeed) {
        return bidders[listingId][bidder].exists;
    }



    function mint(string memory tokenURI, address minterAddress) public returns (uint256) {
        tokenCounter++;
        uint256 tokenId = tokenCounter;

        _safeMint(minterAddress, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit Minted(minterAddress, tokenId, tokenURI);

        return tokenId;
    }

    function createAuctionListing (uint256 price, uint256 tokenId, uint256 durationInSeconds) public returns (uint256) {
        listingCounter++;
        uint256 listingId = listingCounter;

        uint256 startAt = block.timestamp;
        uint256 endAt = startAt + durationInSeconds;

        listings[listingId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            price: price,
            netPrice: price,
            status: STATUS_OPEN,
            startAt: startAt,
            endAt: endAt
        });

        _transfer(msg.sender, address(this), tokenId);

        emit AuctionCreated(listingId, msg.sender, price, tokenId, startAt, endAt);

        return listingId;
    }

    function bid(uint256 listingId) public payable nonReentrant {
        require(isAuctionOpen(listingId), 'auction has ended');
        Listing storage listing = listings[listingId];
        require(msg.sender != listing.seller, "Cannot bid on what you own");
        require(!isBidder(listingId, msg.sender), "You can not bid twice in the same auction");
        //require(msg.sender != highestBidder[listingId], "you can not bid twice");
        console.log("bids",bids[listingId][msg.sender]);
        uint256 newBid = bids[listingId][msg.sender] + msg.value;
        require(newBid >= listing.price + commitmentPrice, "Cannot bid below the latest bidding price and the commitment price");
        require(newBid >= bids[listingId][highestBidder[listingId]], "Cannot bid below the latest highest bidding price");
        console.log("bids",bids[listingId][msg.sender]);
        console.log("listing.price",listing.price);

        bids[listingId][msg.sender] += msg.value;
        bidders[listingId][msg.sender].exists = true;
        bidders[listingId][msg.sender].commitmentPrice = commitmentPrice;
        bidders[listingId][msg.sender].biddingPrice += msg.value ;

        highestBidder[listingId] = msg.sender;
        console.log("minAuctionIncrement",minAuctionIncrement);
        uint256 incentive = listing.price / minAuctionIncrement;
        listing.price = listing.price + incentive;
        console.log("new listing.price",listing.price);
        emit BidCreated(listingId, msg.sender, newBid);
    }

    // function highestBidder(uint256 listingId, address _address) public returns(address winner){
    //     Bidders[] memory rec = new Bidders[listingId][](ipCount);
        // function AllIps() public view returns (IParameter[] memory){
        // IParameter[] memory rec = new IParameter[](ipCount);
        // for (uint i = 0; i < ipCount; i++) {
        //     rec[i] =  bidders[i];
        // }
        // return rec;
    // }
    // }


    function completeAuction(uint256 listingId) public payable nonReentrant {
        require(!isAuctionOpen(listingId), 'auction is still open');

        Listing storage listing = listings[listingId];
        address winner = highestBidder[listingId]; 
        require(
            msg.sender == listing.seller || msg.sender == winner, 
            'only seller or winner can complete auction'
        );

        if(winner != address(0)) {
           _transfer(address(this), winner, listing.tokenId);

            uint256 amount = bids[listingId][winner]; 
            console.log("transferred amount", amount);
            bids[listingId][winner] = 0;
            _transferFund(payable(listing.seller), amount);

        } else {
            _transfer(address(this), listing.seller, listing.tokenId);
        }

        listing.status = STATUS_DONE;

        emit AuctionCompleted(listingId, listing.seller, winner, bids[listingId][winner]);
    }

    function withdrawBid(uint256 listingId) public payable nonReentrant {
        require(isAuctionExpired(listingId), 'auction must be ended');
        require(highestBidder[listingId] != msg.sender, 'highest bidder cannot withdraw bid');

        uint256 balance = bids[listingId][msg.sender];
        // uint256 balance = bidders[listingId][msg.sender].commitmentPrice + bidders[listingId][msg.sender].biddingPrice;
        console.log("balance", balance);
        //bids[listingId][msg.sender] = 0;
        _transferFund(payable(msg.sender), balance);

        emit WithdrawBid(listingId, msg.sender, balance);

    }

    function isAuctionOpen(uint256 id) public view returns (bool) {
        return
            listings[id].status == STATUS_OPEN &&
            listings[id].endAt > block.timestamp;
    }


    function isAuctionExpired(uint256 id) public view returns (bool) {
        return listings[id].endAt <= block.timestamp;
    }


    function _transferFund(address payable to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        require(to != address(0), 'Error, cannot transfer to address(0)');

        (bool transferSent, ) = to.call{value: amount}("");
        require(transferSent, "Error, failed to send Ether");
    }

}
