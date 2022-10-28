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

const model_id = "abc";

// process.exit();

const provider = process.env.STARKNET_PROVIDER_BASE_URL === undefined ?
defaultProvider :
new Provider({ baseUrl: process.env.STARKNET_PROVIDER_BASE_URL });
// process.exit();

const starkKeyPair = ec.getKeyPair("873382367534745615739902310396893595206628955636663267709047050258496736479");

// Use your new account address
const account = new Account(
    provider,
    "0x525c9f3bdd135c69c1731dd4cccdb309122fc5105916884a428508db36338e7",
    starkKeyPair
);

console.log(account, account.address);


const erc20Address = "0x05eebdd67ca9ccb979067c8145998d74d7f5cd2bef3f8b4ccddb03b36cfadec3";

const erc721Address = "0x0444c9279db773915d543af617a8155b23592753248c5aa3f49235964cc74ddf";

const tokenAbi = json.parse(
    fs.readFileSync("./dwgame_abi.json").toString("ascii")
);

const erc721 = new Contract(tokenAbi, erc721Address, provider);

erc721.connect(account);

// Execute tx transfer of 10 tokens
console.log(`Invoke Tx - `);


const dowhat = "touch";
let transactionHx = "";
switch (dowhat) {
    case "touch" : transactionHx = await touchToEarn();
    break;
    case "upgrade" : transactionHx = await burnToUpgrade();
    break;
    case "unBlindChip" : transactionHx = await unBlindChip();
    break;
    case "reBlindChip" : transactionHx = await reBlindChip();
    break;
    case "estimateFee" : transactionHx = await estimateFee();
    break;
}

// process.exit(0);
// Wait for the invoke transaction to be accepted on StarkNet
console.log(`Waiting for Tx to be Accepted on Starknet - Transfer...`, transactionHx);
await provider.waitForTransaction(transactionHx);

async function touchToEarn() {
    console.log("touchToEarn");
    const proof_data = await getProof(model_id);
    let contractCalldata = [erc20Address, shortString.encodeShortString(model_id), proof_data.length];
    for(let i = 0; i < proof_data.length; i ++) {
        contractCalldata.push(proof_data[i]);
    }
    // const contractCalldata = ["0x616263", white_verify.data.length, white_verify.data[0], white_verify.data[1]];
    console.log("contractCalldata", contractCalldata);
    const { code, transaction_hash: transferTxHash } = await account.execute(
      {
        contractAddress: erc721Address,
        entrypoint: "touchToEarn",
        calldata: contractCalldata,
      },
      undefined,
      { 
        maxFee: "9999999005330002" 
      }
    );

    return transferTxHash
}

async function burnToUpgrade() {
    console.log("burnToUpgrade")
    const { code, transaction_hash: transferTxHash } = await account.execute(
      {
        contractAddress: erc721Address,
        entrypoint: "burnToUpgrade",
        calldata: [erc20Address, 1, 0],
      },
      undefined,
      { 
        maxFee: "9999999005330010" 
      }
    );

    return transferTxHash
}

async function unBlindChip() {
    console.log("unBlindModel")
    const { code, transaction_hash: transferTxHash } = await account.execute(
      {
        contractAddress: erc721Address,
        entrypoint: "unBlindChip",
        calldata: [1, 0],
      },
      undefined,
      { 
        maxFee: "999000995330002" 
      }
    );

    return transferTxHash
}

async function reBlindChip() {
    console.log("reBlindChip");
    const proof_data = await getProof(model_id);
    let contractCalldata = [shortString.encodeShortString(model_id), proof_data.length];
    for(let i = 0; i < proof_data.length; i ++) {
        contractCalldata.push(proof_data[i]);
    }
    contractCalldata.push(1);
    contractCalldata.push(0);
    // const contractCalldata = ["0x616263", white_verify.data.length, white_verify.data[0], white_verify.data[1]];
    console.log("contractCalldata", contractCalldata);
    const { code, transaction_hash: transferTxHash } = await account.execute(
      {
        contractAddress: erc721Address,
        entrypoint: "reBlindChip",
        calldata: contractCalldata,
      },
      undefined,
      { 
        maxFee: "9999999005330006" 
      }
    );

    return transferTxHash
}

async function estimateFee() {
    console.log("estimateFee");
    let res = await provider.getEstimateFee(
      {
        contractAddress: erc721Address,
        entrypoint: "unBlindChip",
        calldata: [1, 0],
      },
      undefined,
      { 
        maxFee: "9999999005330006" 
      }
    );
    console.log("estimate gas result0");
    console.log(res);
}

async function getProof(m_id) {

    let synchronous_post = function (url, params) {
        return new Promise(function (resolve, reject) {
            const headers = {
                "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBZGRyZXNzIjoiMHg1MjVjOWYzYmRkMTM1YzY5YzE3MzFkZDRjY2NkYjMwOTEyMmZjNTEwNTkxNjg4NGE0Mjg1MDhkYjM2MzM4ZTciLCJleHAiOjE2NjcyOTI1MTksImlhdCI6MTY2NjA4MjkxOSwiaXNzIjoiZHdiYWNrZW5kIiwic3ViIjoiZHd3ZWIifQ.5oCJzN2pusN6hgRtCLrSbaqfUX14RawUu5SPOg9YJZE"
            }
            request.post(
                { 
                    url: url,
                    json: params, 
                    headers: headers
                }, (error, res, body) => {
                if (error) {
                    reject(error);
                } else {
                    resolve(body);
                }
            });
        });
    }

    let syncBody = async function (url, params) {
        // let url = "http://www.baidu.com/";
        var url = url;
        let body = await synchronous_post(url, params);
        // console.log('##### BBBBB', body);
        return body;
    }

    var white_verify = await syncBody('https://api.desider.com/dwgo/api/sn/user/white_verify', {
        m_id: m_id
    });	//函数外部使用

    // console.log("white_verify", white_verify);
    if(white_verify.code != 0) {
        console.log("model err");
        return [];
    } else {
        return white_verify.data;
    }

}