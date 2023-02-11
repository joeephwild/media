// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract FilMedia {
    address public owner;
    struct Content {
        uint256 id;
        string title;
        string name;
        string file;
        string video;
        string image;
        string category;
        string description;
        address owner;
        address buyer;
        bool isSold;
        uint256 price;
    }

    struct ArtistStruct {
        string name;
        address owner;
        string image;
        string coverImage;
        string category;
        string description;
        string title;
        uint256 listener;
        uint256 supporters;
    }

    ArtistStruct[] public artist;
    Content[] public playlist;
    Content[] public music;
    mapping(address => mapping(address => bool)) public followers;
    mapping(uint256 => Content) public musics;
    mapping(address => ArtistStruct) public artists;
    mapping(address => uint256) public playlists;

    uint256 public numberOfMusic;
    //uint256 musicCount;
    uint256 public numberOfFollowers;
    //to keep track of number of supporters
    uint256 public numberOfSupporter;
    //to keep track of plays
    uint256 public idOfAccount;

    //create an accouunt
    function createAccount(
        string memory _name,
        string memory _image,
        string memory _coverImage,
        string memory _category,
        string memory _description;
        string memory _title
    ) external returns(uint256) {
        ArtistStruct storage creator = artists[msg.sender];
        creator.name = _name;
        creator.owner = msg.sender;
        creator.image = _image;
        creator.coverImage = _coverImage;
        creator.category = _category;
        creator.description = _description;
        creator.title = _title;
        creator.listener = numberOfFollowers;
        creator.supporters = numberOfSupporter;
        artist.push(creator);
        idOfAccount++;
        return idOfAccount;
    }

    //get all artist
    function getAllArtist() public view returns (ArtistStruct[] memory) {
        return artist;
    }

    //update a particular section of an account
    function updateAccount(address _owner, string memory data, uint256 option) external {
        ArtistStruct storage creator = artists[_owner];
        require(creator.owner == msg.sender, "only account owner");
        if (option == 0) {
            creator.name = data;
        } else if (option == 2) {
            creator.image = data;
        } else if (option == 3) {
            creator.coverImage = data;
        }
    }

    //delete an account
    function deleteAccount(address _pubkey) external {
        ArtistStruct storage creator = artists[_pubkey];
        require(creator.owner == msg.sender, "only account owner");
        delete artists[_pubkey];
    }

    //upload a new music
    function uploadContent(
        string memory _title,
        string memory _name,
        string memory _file,
        string memory _video,
        string memory _image,
        string memory _category,
        uint256 _price
    ) external returns (uint256) {
        require(msg.sender != address(0), "address cant be empty");
        Content storage art = musics[numberOfMusic];
        //require(music.owner == msg.sender, "");
        art.title = _title;
        art.name = _name;
        art.file = _file;
        art.video = _video;
        art.image = _image;
        art.category = _category;
        art.owner = msg.sender;
        art.buyer = address(0);
        art.isSold = false;
        art.price = _price;
        music.push(art);
        numberOfMusic++;
        emit Uploaded(
            numberOfMusic,
            _title,
            _name,
            _file,
            _video,
            _image,
            _category,
            msg.sender,
            address(0),
            false,
            _price
        );
        return numberOfMusic;
    }

    event Uploaded(
        uint256 id,
        string title,
        string name,
        string file,
        string video,
        string image,
        string category,
        address owner,
        address buyer,
        bool isSold,
        uint256 price
    );

    //follow abd account
    function followAnAccount(address _artist, address _listener) public {
        followers[_artist][_listener] = true;
        numberOfFollowers += 1;
    }

    //unfollow an account
    function unfollowAnAccount(address _artist, address _listener) public {
        delete followers[_artist][_listener];
        numberOfFollowers -= 1;
    }

    //get number of followers
    function getFollowerCount() public view returns (uint256) {
        return numberOfFollowers;
    }

    //Get every list of music in the blockchain
    function getAllContent() public view returns (Content[] memory) {
        Content[] memory allMusic = new Content[](numberOfMusic);

        for (uint256 i = 0; i < numberOfMusic; i++) {
            Content storage item = musics[i];

            allMusic[i] = item;
        }
        return allMusic;
    }

    event ItemPurchased(uint256 id, address buyer, uint price);

    function addToPlaylist(uint256 id) external {
        require(musics[id].buyer == msg.sender, "only when brought");
        require(musics[id].owner != msg.sender, "only when brought");
        Content storage item = musics[id];
        playlist.push(item);
    }

    function getPlaylist() external view returns (Content[] memory) {
        return playlist;
    }

    function purchaseTrack(uint256 _id) public payable {
        require(msg.value == musics[_id].price, "Incorrect payment amount.");
        require(musics[_id].owner != msg.sender, "Item already belongs to you.");
        payable(musics[_id].owner).transfer(musics[_id].price);
        musics[_id].buyer = msg.sender;
        musics[_id].isSold = true;
        numberOfSupporter++;
        emit ItemPurchased(_id, msg.sender, musics[_id].price);
    }
}
