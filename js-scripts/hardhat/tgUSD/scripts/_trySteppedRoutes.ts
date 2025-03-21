import { ethers } from 'hardhat';
import fs from 'fs';
import path from 'path';
import { AddressLike, ZeroAddress } from 'ethers';

const routerAddress = '0x16c6521dff6bab339122a0fe25a9116693265353';
const routerAbi = [
  'function get_dy(address[11], uint256[5][5], uint256, address[5]) external view returns (uint256)'
];

async function tryStepedRoute() {
  const transfersPath = path.resolve(__dirname, '../data/transfers.json');
  const verifiedRoutesPath = path.resolve(__dirname, '../data/verified-transfers.json');

  const transfers = JSON.parse(fs.readFileSync(transfersPath, 'utf8'));
  const verifiedRoutes = JSON.parse(fs.readFileSync(verifiedRoutesPath, 'utf8'));

  const verifiedParamsMap = new Map<string, any>();
  verifiedRoutes.params.forEach((param: any) => {
    verifiedParamsMap.set(param.route.display, param.result);
  });

  const provider = ethers.provider;
  const router = new ethers.Contract(routerAddress, routerAbi, provider);

  const stepResults = [];
  const errors = [];

  for (const routeGroup of transfers) {
    const routeAddresses = [];
    const swapParamsFull = [];
    const amountIn = ethers.parseUnits('100', 9);
    routeAddresses.push(routeGroup[0].pool);
    
    for (const step of routeGroup) {
      const poolAddress = step.pool.toLowerCase();
      if (!verifiedParamsMap.has(step.display)) {
        errors.push({ step, error: 'Missing verified route parameters' });
        continue;
      }
      
      const stepParams = verifiedParamsMap.get(step.display);
      routeAddresses.push(poolAddress, step.out);
      swapParamsFull.push(stepParams.swapParams);
    }

    // Fill remaining slots with ZeroAddress and default swap params
    while (routeAddresses.length < 11) {
      routeAddresses.push(ZeroAddress);
    }
    while (swapParamsFull.length < 5) {
      swapParamsFull.push([0, 0, 0, 0, 0]);
    }
    
    try {
    
      const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
      stepResults.push({ route: routeGroup, output: output.toString(),params: {routeAddresses, swapParamsFull}});
    } catch (error: any) {
      errors.push({ route: routeGroup, error: error.message,params: {routeAddresses, swapParamsFull} });
    }
  }

  const outputPath = path.resolve(__dirname, '../data/steped-routes.json');
  fs.writeFileSync(outputPath, JSON.stringify({ stepResults, errors }, null, 2));
  console.log(`✅ Step results saved to steped-routes.json , valid : ${stepResults.length} , errors :  ${errors.length} `);
}

tryStepedRoute().catch(console.error);