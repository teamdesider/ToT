// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../../src/ITOT721.sol";
import "./DemoERC20.sol";

/* 
* There is a corresponding NFT contract with the NFC physical chip. 
* It has not been verified yet, please verify it yourself if you want to use it
*/
contract DemoERC721 is ERC721, ERC721Burnable, Ownable, ITOT721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // Mapping owner address to token numberMinted
    mapping(uint256 => string) private _tokenURIs;

    mapping(uint256 => uint256) private _tokenLucky;

    mapping(uint256 => uint256) private _token_earn_tm;

    mapping(string => uint256) private _chipTokens;

    //Mutual mapping must be recorded, because it needs to be used when unbinding or resetting
    mapping(uint256 => string) private _tokenToChips;

    uint256 constant EARN_INTERNAL = 300;

    //Merkle
    bytes32 private saleMerkleRoot;
    
    constructor() ERC721("MyToken", "MTK") {}

    function safeMint(address to) public onlyOwner {
    }

    function setSaleMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        saleMerkleRoot = merkleRoot;
    }

    function touchToEarn(address _addr20, string memory chipAddress, bytes32[] calldata merkleProof) external {
        _touchToEarn(_addr20, chipAddress, merkleProof, saleMerkleRoot);
    }

    function _touchToEarn(address _addr20, string memory chipAddress, bytes32[] calldata merkleProof, bytes32 merkleRoot) internal isValidMerkleProof(merkleProof, merkleRoot) {
        uint256 tokenId = _chipTokens[chipAddress];
        //Because of the verification, tokenId starts from 1, 0 is empty and never mint
        if (tokenId == 0) {
            uint256 currentId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            tokenId = currentId + 1;
            _safeMint(msg.sender, tokenId);
            _tokenLucky[tokenId] = 1;
            _chipTokens[chipAddress] = tokenId;
            _tokenToChips[tokenId] = chipAddress;
        } else {
            address owner = ERC721.ownerOf(tokenId);
            require(owner == msg.sender, "only owner can transfer");
        }

        uint256 last_tm = _token_earn_tm[tokenId];
        uint256 curr_tm = block.timestamp;
        require(curr_tm - last_tm > EARN_INTERNAL, "please wait for some time");

        _token_earn_tm[tokenId] = curr_tm;

        uint256 amount = 100 * 1000000000000000000;

        DemoERC20(_addr20).touchToEarn(msg.sender, amount);
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }
    
    function unBlindChip(uint256 tokenId) external {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        require(owner == msg.sender, "only owner can transfer");
        string memory chipAddress = _tokenToChips[tokenId];
        delete _chipTokens[chipAddress];
        _tokenToChips[tokenId] = "";
    }

    function reBlindChipForToken(string memory chipAddress, bytes32[] calldata merkleProof, uint256 tokenId) external {
        _reBlindChipForToken(chipAddress, merkleProof, tokenId, saleMerkleRoot);
    }

    function _reBlindChipForToken(string memory chipAddress, bytes32[] calldata merkleProof, uint256 tokenId, bytes32 merkleRoot) internal isValidMerkleProof(merkleProof, merkleRoot) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        require(owner == msg.sender, "only owner can transfer");
        string memory oldChipAddress = _tokenToChips[tokenId];
        _tokenToChips[tokenId] = chipAddress;
        _chipTokens[oldChipAddress] = tokenId;
        delete _chipTokens[oldChipAddress];
    }
}