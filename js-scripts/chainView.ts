import {ContractFactory, Interface, InterfaceAbi, BytesLike, Fragment, ZeroAddress, BigNumberish, Provider} from "ethers";
import {ethers} from "hardhat";
export const chainView = async <R = any>(abi: InterfaceAbi, bytecode: BytesLike, params: any[], options?: {from?: string; value?: bigint; blockTag?: BigNumberish}): Promise<R> => {
    const provider = ethers.provider;
    const opts: {from?: string; value?: bigint; blockTag?: BigNumberish} = options || {};

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
