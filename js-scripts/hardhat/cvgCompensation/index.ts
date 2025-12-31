import { commonERC20 } from "@tangent/defi-resources";
import { filterAndGetTokenHoldersAmount } from "./erc20Strat/erc20BalanceSnapshot";
import { seedSnapshot } from "./erc721/seed";

const lockingPositionService = "0xc8a6480ed7C7B1C401061f8d96bE7De6f94D3E60"
const stkCvgEth = "0x4b3Bd8906083bDE267A79E4131AF7a6f723960c8"
const stkCvgSdt = "0x865E59EBc3EE9EdD5656cD79b382f5153E466545"
const bondDepository = "0xEa3C304fAb04AA459a5E4712e06Eb22Ef3624420"
const vestingCvg = "0xC929bA60ef82fE55De3bC848dd9453B3b12a0c30"
const cvgFraxBp = "0xa7B0E924c2dBB9B4F576CCE96ac80657E42c3e42"
const cvgEth = "0x004C167d27ADa24305b76D80762997Fa6EB8d9B2"
const multisigDao = "0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7"
const multisigAirdrop = "0xCD6cfCE8c8D3b6Efad27390e87D6931d4078B36c"
const multisigTeam = "0x794C31863B0459039B17479dC638c1948c27FcB9"
const multisigBootstrap = "0x2927D7D70943290529Adc517E8E2Dc1eEE7818b6"
const multisigBribes = "0x46cb1982abeb3df9d92dcc678629c11239ca0bbe"
const cvgCVX = "0x2191df768ad71140f9f3e96c1e4407a4aa31d082"


async function main() {
    // const excludedAddressesCvg = [
    //     lockingPositionService, stkCvgEth, stkCvgSdt, bondDepository,
    //     vestingCvg, cvgFraxBp, cvgEth, multisigDao, multisigAirdrop,
    //     multisigTeam, multisigBootstrap, multisigBribes, cvgCVX].map(a => a.toLowerCase())
    // await filterAndGetTokenHoldersAmount(commonERC20.CVG, "cvg", 19124400, 50_000, excludedAddressesCvg)
    // await filterAndGetTokenHoldersAmount(stkCvgEth, "stkCvgEth", 19633511, 50_000, [])
    // await filterAndGetTokenHoldersAmount(stkCvgSdt, "stkCvgSdt", 19633517, 50_000, [])

    await seedSnapshot("Seed", 0)
    await seedSnapshot("PresaleWL", 1)
    await seedSnapshot("IBO", 2)

}

main()