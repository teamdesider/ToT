import request from "request"
import fs from "fs";
import {
    Account,
    Contract,
    defaultProvider,
    ec,
    json,
    stark,
    Provider,
    number,
    shortString
} from "starknet";


const provider = process.env.STARKNET_PROVIDER_BASE_URL === undefined ?
defaultProvider :
new Provider({ baseUrl: process.env.STARKNET_PROVIDER_BASE_URL });

const starkKeyPair = ec.getKeyPair("873382367534745615739902310396893595206628955636663267709047050258496736479");

// Use your new account address
const account = new Account(
    provider,
    "0x525c9f3bdd135c69c1731dd4cccdb309122fc5105916884a428508db36338e7",
    starkKeyPair
);

console.log(account, account.address);

const erc721Address = "0x015c18c64482285df7340d7db9cdaadb84814d5e703078371cd98a54d38e4a9b";

const tokenAbi = json.parse(
    fs.readFileSync("./dwgame_abi.json").toString("ascii")
);

const erc721 = new Contract(tokenAbi, erc721Address, provider);

erc721.connect(account);
console.log(`Invoke Tx - Transfer 10 tokens back to erc721 contract...`);

const dowhat = "setBaseTokenUri";
let transactionHx = "";
switch (dowhat) {
    case "setBaseTokenUri" : transactionHx = await setBaseTokenUri();
    break;
    case "setMerkleRoot" : transactionHx = await setMerkleRoot();
    break;
}

// process.exit(0);
// Wait for the invoke transaction to be accepted on StarkNet
console.log(`Waiting for Tx to be Accepted on Starknet - Transfer...`, transactionHx);
await provider.waitForTransaction(transactionHx);

async function setBaseTokenUri() {
    console.log("setBaseTokenUri");
    const { code, transaction_hash: transferTxHash } = await account.execute(
        {
          contractAddress: erc721Address,
          entrypoint: "setBaseTokenUri",
          calldata: [2, "186294699441980128189381494265569993580838195856653195382168720835301174887", "5389257203177760959057865227798242600658385010388191279"],
        },
        undefined,
        { 
          maxFee: "999990095330009" 
        }
    );
    return transferTxHash;
}

async function setMerkleRoot() {
    console.log("setMerkleRoot");
    const { code, transaction_hash: transferTxHash } = await account.execute(
        {
          contractAddress: erc721Address,
          entrypoint: "setMerkleRoot",
          calldata: ["660906365176751370884167549084738602661764337276504303123002510575104783648"],
        },
        undefined,
        { 
          maxFee: "9988999005330000" 
        }
    );
    return transferTxHash;
}
  