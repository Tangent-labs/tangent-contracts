import {Client} from "pg";

export async function forceAbi(client: Client, address: string, name: string, isVyper: boolean, abi: any[]) {
    const now = new Date();
    const slicedAddress = address.slice(2);
    let encodedAddress = "\\x" + slicedAddress;

    const stringifiedAbi = JSON.stringify(abi);

    try {
        await client.query("BEGIN");

        await upsertAddresses(client, encodedAddress, slicedAddress, now);
        await upsertSmartContracts(client, name, encodedAddress, slicedAddress, isVyper, now, stringifiedAbi);
        await upsertAddressNames(client, encodedAddress, slicedAddress, name, now);

        await client.query("COMMIT");
    } catch (e) {
        await client.query("ROLLBACK");
        throw e;
    }
}

async function upsertAddressNames(client: Client, encodedAddress: string, slicedAddress: string, name: string, now: Date) {
    const getAddressNamesQuery = `SELECT address_hash FROM public.address_names WHERE UPPER(ENCODE(address_hash,'hex')) = $1;`;
    const getAddressNamesParams = [slicedAddress.toUpperCase()];

    let res = await client.query(getAddressNamesQuery, getAddressNamesParams);
    // We insert
    if (res.rowCount == 0) {
        const insertAddressNameQuery = `INSERT INTO public.address_names(address_hash, name, "primary", inserted_at, updated_at, metadata) VALUES ($1, $2, $3, $4, $5, $6)`;
        res = await client.query(insertAddressNameQuery, [
            encodedAddress, // address hash
            name, // Name
            0, // isPrimary
            now, // updated at
            now, // Nonce
            null,
        ]);
    } else {
        const updateAddressNamesQuery = `UPDATE public.address_names
        SET name=$2, "primary"=true, inserted_at=$3, updated_at=$3
        WHERE UPPER(ENCODE(address_hash, 'hex')) = $1;`;
        res = await client.query(updateAddressNamesQuery, [slicedAddress, name, now]);
    }
}

async function upsertAddresses(client: Client, encodedAddress: string, slicedAddress: string, now: Date) {
    const getAddressQuery = `SELECT hash FROM public.addresses WHERE UPPER(ENCODE(hash,'hex')) = $1;`;
    const getAddressParams = [slicedAddress.toUpperCase()];

    let res = await client.query(getAddressQuery, getAddressParams);
    // We insert
    if (res.rowCount == 0) {
        const insertAddressQuery = `INSERT INTO public.addresses(fetched_coin_balance, fetched_coin_balance_block_number, hash, contract_code, inserted_at, updated_at, nonce, decompiled, verified, gas_used, transactions_count, token_transfers_count) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);`;
        const inserAddressParams = [
            0, // fetched coin balance
            0, // fetched_coin_balance_block_number
            encodedAddress, // address hash
            0, // Contract code
            now, // inserted at
            now, // updated at
            0, // Nonce
            0, // Decompiled
            true, // verified
            0, // gas used
            0, // tx count
            0, // token_transfers_count
        ];
        res = await client.query(insertAddressQuery, inserAddressParams);
    }
    // We update
    else {
        const updateAddressesQuery = `UPDATE public.addresses
        SET contract_code='0', verified=true
        WHERE UPPER(ENCODE(hash, 'hex')) = $1;`;
        res = await client.query(updateAddressesQuery, getAddressParams);
    }
}

async function upsertSmartContracts(client: Client, name: string, encodedAddress: string, slicedAddress: string, isVyper: boolean, now: Date, abi: string) {
    const getAddressQuery = `SELECT address_hash FROM public.smart_contracts WHERE UPPER(ENCODE(address_hash,'hex')) = $1;`;
    const getAddressParams = [slicedAddress.toUpperCase()];
    let res = await client.query(getAddressQuery, getAddressParams);
    // We insert
    if (res.rowCount == 0) {
        const insertSmartContractQuery = `INSERT INTO public.smart_contracts(name, compiler_version, optimization, contract_source_code, abi, address_hash, inserted_at, updated_at, constructor_arguments, optimization_runs, evm_version, external_libraries, verified_via_sourcify, is_vyper_contract, partially_verified, file_path, is_changed_bytecode, bytecode_checked_at, contract_code_md5, compiler_settings, verified_via_eth_bytecode_db, license_type, verified_via_verifier_alliance, certified, is_blueprint, language)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26);`;

        res = await client.query(insertSmartContractQuery, [
            name, // Name
            "v0.8.28+commit.7893614a", // Compiler version
            true, // isOptimized
            "Code source placeholder", // Source code
            abi, // ABI
            encodedAddress, // Address
            new Date(),
            new Date(),
            null, // Constructor args
            250, // runs opti
            "default", // EVM version
            null, // external_libraries
            false, // verified_via_sourcify
            isVyper, // is_vyper_contract
            1, // partially_verified
            ".sol", // file_path
            false, // is_changed_bytecode
            now, // bytecode_checked_at
            0, // contract_code_md5
            null, // compiler_settings
            false, // verified_via_eth_bytecode_db
            1, // License type
            false, // verified_via_verifier_alliance
            null, // certified
            false, // is_blueprint
            1, // language
        ]);
    }
    // We update
    else {
        const updateAddressesQuery = `UPDATE public.smart_contracts
        SET name=$2, abi=$3, is_vyper_contract=$4, partially_verified=true
        WHERE UPPER(ENCODE(address_hash, 'hex')) = $1;`;
        const updateParams = [slicedAddress, name, abi, isVyper];
        res = await client.query(updateAddressesQuery, updateParams);
    }
}
