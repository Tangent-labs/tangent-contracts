import { ethers } from 'hardhat';
import fs from 'fs';
import path from 'path';
import { AddressLike, ZeroAddress } from 'ethers';

const routerAddress = '0x16c6521dff6bab339122a0fe25a9116693265353';
const routerAbi = [
  'function get_dy(address[11], uint256[5][5], uint256, address[5]) external view returns (uint256)',
];


type SwapParam = [number, number, number, number, number];
type Transfer = {
  in: string;
  pool: string;
  out: string;
  display: string
}


async function getPoolInfo(poolAddress: AddressLike): Promise<{ coins: string[] }> {
  const poolAbi = [
    'function coins(uint256) external view returns (address)'
  ];

  const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);

  const coinCount = 4;
  const coins: string[] = [];

  for (let i = 0; i < coinCount; i++) {
    try {
      const coinAddress = await poolContract.coins(i);
      coins.push(coinAddress);
    } catch {
    }
  }
  return { coins };
}

async function determineSwapParams(poolAddress: AddressLike, route: Transfer, amountIn: bigint) {


  const { coins } = await getPoolInfo(poolAddress);


  const [deployer] = await ethers.getSigners();
  const router = new ethers.Contract(routerAddress, routerAbi, deployer);
  const routeAddresses = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)]
  const ZEROS = [0, 0, 0, 0, 0];
  const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  const poolTypes = [1, 2, 3, 4, 10, 20, 30];

  for (let i = 0; i < poolTypes.length; i++) {
    for (let j = 0; j < swapTypes.length; j++) {
      const currentSwapParams = [0, 1, poolTypes[i], swapTypes[j], coins.length]
      const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
      try {
        const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
        if (output > 0n) {
          return { swapType: swapTypes[j], poolType: poolTypes[i], swapParams:currentSwapParams, ...route, coins };
        }
      } catch (e: any) {
        // Ignore errors
      }
    }
  }
  throw new Error('No valid params found');
}


async function main() {
  const params = [];
  const errors = [];

  // Updated file path to use transfers.json
  const filePath = path.resolve(__dirname, '../data/transfers.json');
  const transfers = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  const amountIn = ethers.parseUnits('100', 9);
  const pools = new Map<string, Transfer>();

  // Extract pools and their respective input/output tokens
  transfers.forEach((routeGroup: any[]) =>
    routeGroup.forEach(route => {
      if (route.pool && route.in && route.out) {
        pools.set(route.display, route);
      } else {
        console.error('incomplete route found', route);
      }
    })
  );

  for (const [_, route] of pools.entries()) {
    

    try {
      // No more RPC call; we use tokenIn & tokenOut from JSON

      const result = await determineSwapParams(route.pool, route, amountIn);
      params.push({ route, result });
    } catch (error: any) {
      errors.push({  error: error.message, route });
    }
  }

  const outputPath = path.resolve(__dirname, '../data/verified-transfers.json');
  fs.writeFileSync(outputPath, JSON.stringify({ params, errors }, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2));

  console.log('✅ Results saved to verified-transfers.json', `valid: ${params.length}`, `errors: ${errors.length}`);
}


main().catch((error) => {
  console.error(error);
  process.exit(1);
});
