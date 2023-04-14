// SPDX-License-Identifier: UNLICENSED
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

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price; // display price
        uint256 netPrice; // actual price
        uint256 startAt;
        uint256 endAt; 
        uint256 revealEndtime;
        uint8 status;
    }

    event Minted(address indexed minter, uint256 nftID, string uri);
    event AuctionCreated(uint256 listingId, address indexed seller, uint256 price, uint256 tokenId, uint256 startAt, uint256 endAt);
    event BidCreated(uint256 listingId, address indexed bidder, uint256 bid);
    event AuctionCompleted(uint256 listingId, address indexed seller, address indexed bidder, uint256 bid);
    event WithdrawBid(uint256 listingId, address indexed bidder, uint256 bid);
    event AuctionEnded(address winner, uint highestBid);

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => mapping(address => uint256)) public bids;
    mapping(uint256 => address) public highestBidder;
    mapping(uint256 => uint256) public highestBid;

    uint private bidCount = 0;
    uint private revealedCount = 0;

    constructor() ERC721("piggyNFT", "PNFT") {
        tokenCounter = 0;
        listingCounter = 0;
    }
    struct Bid {
        bytes32 sealedBid;
        uint depositAmt;
        bool exists;
    }

    mapping (uint256 => mapping(address => Bid[])) public bidMap;
    
    function mint(string memory tokenURI, address minterAddress) public returns (uint256) {
        tokenCounter++;
        uint256 tokenId = tokenCounter;

        _safeMint(minterAddress, tokenId);
        _setTokenURI(tokenId, tokenURI);

        emit Minted(minterAddress, tokenId, tokenURI);
        return tokenId;
    }

    function createAuctionListing (uint256 price, uint256 tokenId, uint256 durationInSeconds, uint256 revealInSeconds) public returns (uint256) {
        listingCounter++;
        uint256 listingId = listingCounter;
        uint256 startAt = block.timestamp;
        uint256 endAt = startAt + durationInSeconds;
        uint256 revealEndtime = endAt + revealInSeconds;

        listings[listingId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            price: price,
            netPrice: price,
            status: STATUS_OPEN,
            startAt: startAt,
            endAt: endAt,
            revealEndtime: revealEndtime
        });

        _transfer(msg.sender, address(this), tokenId);

        emit AuctionCreated(listingId, msg.sender, price, tokenId, startAt, endAt);

        return listingId;
    }

    function sealBid(uint _value, string calldata _passcode) public view returns (bytes32) {
        return keccak256(abi.encodePacked(_value,  _passcode, msg.sender));
    }

    function bid(uint256 listingId, bytes32 _sealedBid) public payable nonReentrant {
        require(isAuctionOpen(listingId), 'auction has ended');
        Listing storage listing = listings[listingId];
        require(msg.sender != listing.seller, "Cannot bid on what you own");        
        require(bidMap[listingId][msg.sender].length < 1,"There can only be one bid per account");
        uint256 newBid = bids[listingId][msg.sender] + msg.value;
        require(newBid >= listing.price, "Cannot bid below the latest bidding price");
        require(msg.value > 0,"You can't bid nothing");
        // console.log("bids",bids[listingId][msg.sender]);
        // console.log("listing.price",listing.price);
       bids[listingId][payable(msg.sender)] = msg.value;
        uint256 incentive = listing.price / minAuctionIncrement;
        listing.price = listing.price + incentive;
        
        bidMap[listingId][msg.sender].push(Bid({                               
            sealedBid: _sealedBid,                   
            depositAmt: msg.value,  
            exists: true                 
        }));
         bidCount +=1;
        emit BidCreated(listingId, msg.sender, newBid);
    }

    function reveal(uint256 listingId, uint _value, string memory _passcode) external {
        require(isAuctionExpired(listingId), 'Wait until the auction ended');
        require(isReavelTimeOpen(listingId), 'You missed it,you no longer participating you can withdraw your money.');
        Bid storage myBid = bidMap[listingId][msg.sender][0];  
        uint value = _value;
        string memory passcode = _passcode;
        require(myBid.sealedBid == keccak256(abi.encodePacked(value, passcode, msg.sender)),"The sealedBid doesn't match the hash");
        if(myBid.depositAmt == value){
			myBid.sealedBid = bytes32(0);
			if(!checkBid(listingId,msg.sender, value)) { 
                payable(msg.sender).transfer(myBid.depositAmt); 
            }
        }      
        revealedCount +=1; 
    } 

    function checkBid(uint256 listingId, address _bidder, uint _value) internal returns(bool success) {      
        uint value = _value;
        address bidder = _bidder;
        if (value <= highestBid[listingId]){
            bids[listingId][payable(msg.sender)] = value;
            return false;       //not a higher bid
        }

        if (highestBidder[listingId] != address(0)) {                  
           bids[listingId][highestBidder[listingId]] += highestBid[listingId]; 
        }
        highestBid[listingId] = value;                                
        highestBidder[listingId] = bidder;
        return true;            //a higher bid
    }

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
        require(!isReavelTimeOpen(listingId), 'Not yet, wait until the revealing time ended.');
        uint256 balance = bids[listingId][msg.sender];
        console.log("balance", balance);
        if(balance != 0){
             console.log("balance", balance);
            _transferFund(payable(msg.sender), balance);
            bids[listingId][msg.sender] = 0;
        }
        else {
            console.log("Money already withdrawn.");
        }
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

    function isReavelTimeOpen(uint256 id) public view returns (bool) {
        
        return
            listings[id].status == STATUS_OPEN &&
            listings[id].revealEndtime > block.timestamp;
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
