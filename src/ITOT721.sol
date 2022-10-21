
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITOT721{

    // @description: Scan the model to get tokens, When the model has no corresponding NFT, generate an NFT for the model
    // @param {address} _addr20 Token contract address that can be obtained
    // @param {string} chipAddress NFC chip address of the entity model
    // @param {bytes32[] calldata} merkleProof Information required for verification of whether the model chip address is in the whitelist
    function touchToEarn(address _addr20, string memory chipAddress, bytes32[] calldata merkleProof) external;

    // @description: Remove the chip information corresponding to the tokenId, the chip can no longer obtain tokens in the future
    // @param {uint256} tokenId NFT tokenId to unbind
    function unBlindChip(uint256 tokenId) external;

    // @description: 
    // @param {string memory} New NFC chip address of the entity model 
    // @param {bytes32[] calldata} Information required for verification of whether the model chip address is in the whitelist
    // @param {uint256} tokenId The tokenId that needs to reset the chip
    function reBlindChipForToken(string memory chipAddress, bytes32[] calldata merkleProof, uint256 tokenId) external;
}