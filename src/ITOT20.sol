
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITOT20{
    // @description: Add a contract whitelist, only addresses in the whitelist can call the specified method
    // @param {address} _newEntry
    function addWhitelist(address _newEntry) external;

    // @description: Hold the NFT in the specified ERC721 contract, you can receive the tokens according to the rules
    // Only provide calls in whitelisted ERC721 contracts 
    // @param {address} addr Who can get the token, msg.sender is used in the ERC721 contract, so there is no security issue
    // @param {uint256} amount The number of tokens that can be received
    function touchToEarn(address addr, uint256 amount) external;
}