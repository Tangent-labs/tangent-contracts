import {Client} from "pg";

async function connectDb() {
    const client = new Client({
        user: "blockscout",
        host: "176.143.254.58",
        database: "blockscout",
        password: "ceWb1MeLBEeOIfk65gU8EjF8",
        port: 7432, // Par défaut PostgreSQL utilise 5432
    });
    client.connect();
    return client;
}
async function insertAddresses(address: string, name: string) {
    const client = await connectDb();

    const query = `INSERT INTO public.addresses(fetched_coin_balance, fetched_coin_balance_block_number, hash, contract_code, inserted_at, updated_at, nonce, decompiled, verified, gas_used, transactions_count, token_transfers_count) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *;`;
    const values = [0, 0, Buffer.from(address, "hex"), 0, new Date(), new Date(), 0, 0, 1, 0, 0, 0];

    try {
        const res = await client.query(query, values);
        console.log("✅ Addresses added :", res.rows[0]);
    } catch (err) {
        console.error("❌ Erreur lors de l’insertion", err);
    } finally {
        client.end();
    }
}

async function insertSmartContract(address: string, name: string) {
    const abi = [
        {
            constant: true,
            inputs: [],
            name: "totalSupply",
            outputs: [
                {
                    name: "",
                    type: "uint256",
                },
            ],
            payable: false,
            stateMutability: "view",
            type: "function",
        },
        {
            constant: true,
            inputs: [
                {
                    name: "_owner",
                    type: "address",
                },
            ],
            name: "balanceOf",
            outputs: [
                {
                    name: "balance",
                    type: "uint256",
                },
            ],
            payable: false,
            stateMutability: "view",
            type: "function",
        },
        {
            constant: false,
            inputs: [
                {
                    name: "_spender",
                    type: "address",
                },
                {
                    name: "_value",
                    type: "uint256",
                },
            ],
            name: "approve",
            outputs: [
                {
                    name: "success",
                    type: "bool",
                },
            ],
            payable: false,
            stateMutability: "nonpayable",
            type: "function",
        },
        {
            constant: true,
            inputs: [
                {
                    name: "_owner",
                    type: "address",
                },
                {
                    name: "_spender",
                    type: "address",
                },
            ],
            name: "allowance",
            outputs: [
                {
                    name: "remaining",
                    type: "uint256",
                },
            ],
            payable: false,
            stateMutability: "view",
            type: "function",
        },
        {
            constant: false,
            inputs: [
                {
                    name: "_to",
                    type: "address",
                },
                {
                    name: "_value",
                    type: "uint256",
                },
            ],
            name: "transfer",
            outputs: [
                {
                    name: "success",
                    type: "bool",
                },
            ],
            payable: false,
            stateMutability: "nonpayable",
            type: "function",
        },
        {
            constant: false,
            inputs: [
                {
                    name: "_from",
                    type: "address",
                },
                {
                    name: "_to",
                    type: "address",
                },
                {
                    name: "_value",
                    type: "uint256",
                },
            ],
            name: "transferFrom",
            outputs: [
                {
                    name: "success",
                    type: "bool",
                },
            ],
            payable: false,
            stateMutability: "nonpayable",
            type: "function",
        },
        {
            anonymous: false,
            inputs: [
                {
                    indexed: true,
                    name: "from",
                    type: "address",
                },
                {
                    indexed: true,
                    name: "to",
                    type: "address",
                },
                {
                    indexed: false,
                    name: "value",
                    type: "uint256",
                },
            ],
            name: "Transfer",
            type: "event",
        },
        {
            anonymous: false,
            inputs: [
                {
                    indexed: true,
                    name: "owner",
                    type: "address",
                },
                {
                    indexed: true,
                    name: "spender",
                    type: "address",
                },
                {
                    indexed: false,
                    name: "value",
                    type: "uint256",
                },
            ],
            name: "Approval",
            type: "event",
        },
    ];

    const client = await connectDb();
    const query = `INSERT INTO public.smart_contracts(name, compiler_version, optimization, contract_source_code, abi, address_hash, inserted_at, updated_at, constructor_arguments, optimization_runs, evm_version, external_libraries, verified_via_sourcify, is_vyper_contract, partially_verified, file_path, is_changed_bytecode, bytecode_checked_at, contract_code_md5, compiler_settings, verified_via_eth_bytecode_db, license_type, verified_via_verifier_alliance, certified, is_blueprint, language)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26);`;
    const values = [
        name,
        "v0.8.28+commit.7893614a",
        true,
        12,
        JSON.stringify(abi),
        Buffer.from(address, "hex"),
        new Date(),
        new Date(),
        null,
        250,
        0,
        null,
        true,
        true,
        0,
        0,
        0,
        null,
        0,
        null,
        null,
        0, //License type
        null,
        null,
        null,
        1,
    ];

    try {
        const res = await client.query(query, values);
        console.log("✅ SmartContract added :", res.rows[0]);
    } catch (err) {
        console.error("❌ Erreur lors de l’insertion", err);
    } finally {
        client.end();
    }
}

insertSmartContract("4DEcE678ceceb27446b35C672dC7d61F30bAD69E", "crvUSD-USDC");
