import { commonERC20 } from "@tangent/defi-resources";
import { recomposeBalancesForConvexWithLogs, recomposeBalancesForERC20WithLogs } from "./erc20Strat/erc20BalanceSnapshot";
import { vestingSnapshot } from "./erc721/vestingTypes";
import { lockSnapshot } from "./erc721/lock";
import { findConvexId, getLpDetails } from "./lp/getLpDetails";
import { ethers } from "hardhat";

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
const multisigPod = "0xd2c46b4c28f4b7976d9f87687863c46bb2f71dbb"
const cvgCVX = "0x2191df768ad71140f9f3e96c1e4407a4aa31d082"

const cvgFraxBp_Lp = "0x421E13b4e805993A0d50aD8c6c47A4F693f04424"
const cvgFraxBp_CurveGauge = "0x8a111b47b31bba40c2f0d2f9a8cf6b6c4b50114e"
const cvgFraxBp_StakeDaoGauge = ""   // TODO This is empty
const cvgFraxBp_ConvexRewardToken = "0x0736b746F53826A1eEC888a05EBF592AF68946Db"
const cvgFraxBp_ConvexWrapperFrax = "0x7b465174a93a6d0602fd4ea99eec86c07e5e1568"


const fraxDeployer = "0x5180db0237291a6449dda9ed33ad90a38787621c" // received some LP in fees
const cvgETH_Lp = "0x004C167d27ADa24305b76D80762997Fa6EB8d9B2"
const cvgEth_StakeDaoGauge = "0xd79d3329560489835265d4d100583f21ac9c4a3e"
const cvgEth_ConvexRewardToken = "0x5489a4276AA4cf57ec28Ae0619215A20fE2B2dCe"
const cvgEth_StakeDaoStakerInConvex = "0x7b61b1a0ceda2f01f33be885a3a34c95b38ad118"

const stakeDaoVoter = "0x52f541764e6e90eebc5c21ff570de0e2d63766b6"
const convexVoter = "0x989aeb4d175e16225e39e87d0d97a3360524ad80"

const transferTopic = ethers.keccak256(ethers.toUtf8Bytes("Transfer(address,address,uint256)"))
export const stakedTopic = ethers.keccak256(ethers.toUtf8Bytes("Staked(address,uint256)"));
export const withdrawnTopic = ethers.keccak256(ethers.toUtf8Bytes("Withdrawn(address,uint256)"));

async function main() {
    const excludedAddressesCvg = [
        lockingPositionService, stkCvgEth, stkCvgSdt, bondDepository,
        vestingCvg, cvgFraxBp, cvgEth, multisigDao, multisigAirdrop,
        multisigTeam, multisigBootstrap, multisigBribes, cvgCVX, multisigPod].map(a => a.toLowerCase())
    // CVG
    await recomposeBalancesForERC20WithLogs(
        commonERC20.CVG,
        "cvg",
        excludedAddressesCvg,
        1
    )
    // // StkCvgEth
    // await recomposeBalancesForERC20WithLogs(
    //     stkCvgEth,
    //     "stkCvgEth",
    //     [],
    //     0
    // )
    // // StkCvgSdt
    // await recomposeBalancesWithLogs(
    //     stkCvgSdt,
    //     "stkCvgSdt",
    //     [],
    //     0,
    //     [transferTopic],
    //     recomposeERC20Holders
    // )
    // await vestingSnapshot("Seed", 0, "0x06FEB7a047e540B8d92620a2c13Ec96e1FF5E19b")
    // await vestingSnapshot("PresaleWL", 1, "0xc9740aa94A8A02a3373f5F1b493D7e10d99AE811")
    // await vestingSnapshot("IBO", 2, "0x5F02134C35449D9b6505723A56b02581356320fB")
    // await lockSnapshot()


    ////////////// CVG-FRAXBP ///////////////

    // CVG-FRAXBP LP
    await recomposeBalancesForERC20WithLogs(
        cvgFraxBpLp,
        "cvgFraxBp_LP",
        [cvgFraxBpCurveGauge, fraxDeployer],
        0
    )

    // CVG-FRAXBP Curve Gauge
    await recomposeBalancesForERC20WithLogs(
        cvgFraxBpCurveGauge,
        "cvgFraxBp_Curve_Gauge",
        [stakeDaoVoter, convexVoter],
        0
    )

    // CvgFraxBp Convex
    await recomposeBalancesForConvexWithLogs(
        cvgFraxBpConvexRewardToken,
        "cvgFraxBp_Convex_Token",
        [cvgFraxBpConvexWrapperFrax],
        0
    )


    // CVG-FRAXBP Convex Frax
    await recomposeBalancesForERC20WithLogs(
        cvgFraxBpConvexWrapperFrax,
        "cvgFraxBp_Convex_Frax",
        [],
        0
    )

    // // CVG-FRAXBP StakeDao Gauge
    // await recomposeBalancesWithLogs(
    //     cvgFraxBpStakeDaoGauge,
    //     "cvgFraxBp_StakeDao_Gauge",
    //     [], //TODO fill this
    //     0,
    //     [transferTopic],
    //     recomposeERC20Holders
    // )

    ////////////// CVG-ETH ///////////////


    // CvgEth Convex
    // await recomposeBalancesWithLogs(
    //     cvgFraxBpConvexRewardToken,
    //     "cvgEth_Convex",
    //     [multisigPod, cvgEth_StakeDao_staker_in_convex],
    //     0,
    //     [stakedTopic, withdrawnTopic],
    //     recomposeConvexHolders
    // )

    // await getLpDetails(cvgETH, "cvgETH", 19379915, 50_000, [], 0)

}



main()