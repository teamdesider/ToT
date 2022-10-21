// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./ITOT20.sol";

/*
* Token contracts that can be obtained by scanning NFC
* It has not been verified yet, please verify it yourself if you want to use it
*/
contract DemoERC20 is ERC20, Ownable, ITOT20 {
    
    // only white contract can read some functions
    mapping(address => bool) public whitelist;

    constructor() ERC20("MyToken", "MTK") {}

    // @description: Add an ERC721 contract that allows calling this contract
    // @param {address} _newEntry ERC721 contracts that allow calling this contract
    function addWhitelist(address _newEntry) external onlyOwner {
        whitelist[_newEntry] = true;
    }

    // @description: ERC721 contract call, burn tokens to upgrade holding NFT
    // Only provide calls in whitelisted ERC721 contracts
    // @param {address} from Whose tokens are burned, msg.sender is used in the ERC721 contract, will not be casually introduced
    // @param {uint256} amount The amount of tokens that need to be burned to upgrade
    function burnToUpgrade(address from, uint256 amount) external {
        require(whitelist[msg.sender], "Not in whitelist");
        
        _burn(from, amount);
    }

    // @description: Hold the NFT in the specified ERC721 contract, you can receive the tokens according to the rules
    // Only provide calls in whitelisted ERC721 contracts 
    // @param {address} addr Who can get the token, msg.sender is used in the ERC721 contract, will not be casually introduced
    // @param {uint256} amount The number of tokens that can be received
    function touchToEarn(address addr, uint256 amount) external {
        require(whitelist[msg.sender], "Not in whitelist");

        _mint(addr, amount);
    }
}