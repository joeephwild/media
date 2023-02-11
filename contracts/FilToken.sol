// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FilToken is ERC20 {
    address payable public owner;
    bool  isTransferred;
    uint256 _amount;

    constructor() ERC20("FilToken", "FIT") {
        owner = payable(msg.sender);
        _mint(owner, 10000000 * 10 ** decimals());
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call function");
        _;
    }

    function mint(address payable to, uint256 amount) public onlyOwner  {
        _mint(to, amount);
    }

    function send(address payable to) public  returns(bool) {
        require(isTransferred == false, "transfer is already initiated");
        _amount = 1 * 10 ** decimals();
        _transfer(owner, to, _amount);
        isTransferred = true;
        return isTransferred;
    }
}