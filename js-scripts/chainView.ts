import {ContractFactory, Interface, InterfaceAbi, ContractMethodArgs, BytesLike, Fragment, ZeroAddress, BigNumberish, Provider} from "ethers";
import {ethers} from "hardhat";
export const chainView = async <A extends any[], R>(
    providerOrAbi: Provider | InterfaceAbi,
    abiOrBytecode: InterfaceAbi | BytesLike,
    bytecodeOrParams: BytesLike | ContractMethodArgs<A>,
    paramsOrOptions?: ContractMethodArgs<A> | {from?: string; value?: bigint; blockTag?: BigNumberish},
    options?: {from?: string; value?: bigint; blockTag?: BigNumberish}
): Promise<R> => {
    // Support both old signature (without provider) and new signature (with provider)
    let provider: Provider;
    let abi: InterfaceAbi;
    let bytecode: BytesLike;
    let params: ContractMethodArgs<A>;
    let opts: {from?: string; value?: bigint; blockTag?: BigNumberish} = {};

    if (typeof providerOrAbi === "object" && "call" in providerOrAbi) {
        // New signature: chainView(provider, abi, bytecode, params, options?)
        provider = providerOrAbi as Provider;
        abi = abiOrBytecode as InterfaceAbi;
        bytecode = bytecodeOrParams as BytesLike;
        params = paramsOrOptions as ContractMethodArgs<A>;
        opts = options || {};
    } else {
        // Old signature: chainView(abi, bytecode, params, options?)
        provider = ethers.provider;
        abi = providerOrAbi as InterfaceAbi;
        bytecode = abiOrBytecode as BytesLike;
        params = bytecodeOrParams as ContractMethodArgs<A>;
        opts = paramsOrOptions as {from?: string; value?: bigint; blockTag?: BigNumberish} || {};
    }

    const ChainViewInterface = new Interface(abi);
    const errorNamesExpected = ChainViewInterface.fragments.filter((f): f is Fragment & {name: string} => f.type === "error").map((error) => error.name);
    const ChainView = new ContractFactory(abi, bytecode, provider);

    //get deploy data transaction
    const deploy = await ChainView.getDeployTransaction(...params);
    deploy.from = opts.from || ZeroAddress;
    deploy.value = opts.value || 0n;
    if (opts.blockTag) {
        deploy.blockTag = opts.blockTag;
    }

    //simulate the deployment of the contract
    let dataError: any;
    try {
        await provider.call(deploy);
    } catch (e: any) {
        dataError = e.data?.data;
    }

    //decode data returned by the fake deployment
    const decoded = ChainViewInterface.parseError(dataError);

    const errorName = decoded!.name;
    if (!errorNamesExpected.includes(errorName)) {
        throw new Error(`ChainView Error: ${decoded?.name} with arg ${decoded?.args} at selector ${decoded?.selector}`);
    } else {
        return decoded!.args as R;
    }
};
