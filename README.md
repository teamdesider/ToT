# ToT

### Abstract
This git repository includes all design concepts and components for the project. The project is  mainly coded via cairo, the core code is in the following quote box. The interface in src directory is coded based on solidity, since it is clearer to represent the logic of OOD.   
```
demo/starknet/
```
Starknet directory includes the following files/directory :
```
demo_nft.cairo  -- ERC721 contract
demo_token.cairo -- ERC20 contract
xoroshiro128_next.cairo -- Generating random number contract (helper: the amount of token issuing is random)
dwutils -- utility
```
Test scripts are in the following directory, more detail can be checked in the following Test section.
```
script/
```

### Concept
The website is online： https://www.totia.org/

#### Touch to Earn
Through an NFC chip with its own public-private key pair that can execute asymmetric encryption algorithms, we can interact with physical items to achieve rights confirmation and token distribution on the blockchain
#### Token of Things
Through the built-in ToT chip, physical items' rights can be confirmed on the blockchain. Not only the figure on the desktop, the luxury bag in woman's hand, the personalized clothes, and collections, but all things you can think of can be activated on the blockchain
#### Things of Token
Some on-chain confirmation behaviors can also be materialized, leading to a better experience. For example, the behavior of check-in for participating in offline activities, meeting and adding new friends, merchants issuing points and rewards...

### Design concept and security 
Targeting on the physical model security, the NFC chip that supports RSA encryption is applied to the project. The private key, public key, and RSA algorithm are embedded in the chip which can not be modified.

When scanning the chip with an Application in a phone, the message sent by phone will be encrypted in chips by its private key, then the encrypted message and public key return to the phone; the contract authenticates the message based on the public key; the contract will be called after authentication. 

At the same time, the contract sets a whitelist policy.  The contract authenticates the public key whether it is in the whitelist, true result means the user could get the corresponding token.
 
The whitelist implementation in the project is based on the Merkle algorithm, which is for saving blockchain memory. The Merkle algorithm only records root node content in the contract, and there are some helpers to complete authentication out of the blockchain, though the main authentication is on the chain. There is an alternative implementation for whitelist authentication, which is called complete contract authentication which records the whitelist totally on the blockchain.

Setting whitelist in ERC20 contract, in this case, only the ERC721 contract address in the whitelist can request the ERC20 contract to get tokens.

The Starknet provides an ideal environment for the project, which provides a reasonable gas fee. Since the expensive gas fee for ETH, frequently getting tokens will increase the financial problem. 

### Design Diagram
#### Contract Architecture Design

#### Application flow diagram

### Test
There are test scripts in the scripts directory.

Using starknet.js package interacts with the contract. Before the test, issue the contract on the Starknet test net; the Cairo virtual environment is utilized to issue the contract.
```
starknet-compile demo_nft.cairo --output compile/dwgame_compile.json --abi abi/dwgame_abi.json
starknet deploy --contract compile/dwgame_compile.json --inputs 0x525c9f3bdd135c69c1731dd4cccdb309122fc5105916884a428508db36338e7 --no_wallet
starknet-compile demo_token.cairo --output compile/DwToken_compile.json --abi abi/DwToken_abi.json
starknet deploy --contract compile/DwToken_compile.json --inputs 0x525c9f3bdd135c69c1731dd4cccdb309122fc5105916884a428508db36338e7 --no_wallet
```
#### setting.js
Sets required data for the erc721 contract
- setBaseTokenUri -- set united menu for tokenURL
- setMerkleRoot -- set Merkle root value in the contract, which is required for authentication

#### erc721.js 
There are relative methods for testing ERC721. In this test, touchToEarn is the main method to test. The test has implemented whitelist authentication, the data approved is in script/chip_address.txt 
1. Issue ERC20 and ERC721 contract
2. Add ERC721 contract to the whitelist which is in ERC20 contract
3. Call setMerkleRoot method in ERC721 contract
4. Call touchToEarn method in ERC721 contract 
Note: the contract in the test code completes flow 1~3 by default, flow 4 can be directly tested.

### Authentication helpers out of blockchain
As discussed in the previous section, the Merkel algorithm for whitelist authentication needs helpers out of the blockchain to complete its job. The helper code has been put on the GitHub repository.
#### Merkle directory
The code is in the directory.
```
merkle/
```
main.py -- executing python main.py will provide API services, which provide a contract with authentication information to complete authentication.
merkle.py -- serve for generating auth information, executing python merkle.py can get root value of Merkle tree.
The test is in Cairo virtual environment, and Python version 3.9.

#### The test is in Cairo virtual environment, and Python version 3.9.
