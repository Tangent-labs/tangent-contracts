
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SplitterToken} from "../src/tokens/SplitterToken.sol";

import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {gUSDCvx} from "../src/tokens/gUSDCvx.sol";
import {scvUSDCvx} from "../src/tokens/scvUSDCvx.sol";
import {SplitterTokenComp} from "../src/tokens/SplitterTokenComp.sol";
import {ISdtLiquidityGauge} from "../src/interfaces/externals/ISdtLiquidityGauge.sol";
import {IStakeDaoVault} from "../src/interfaces/externals/IStakeDaoVault.sol";
import {ILlamaVault} from "../src/interfaces/externals/ILlamaVault.sol";

import {ILendRewardSplitter} from "../src/interfaces/internals/ILendRewardSplitter.sol";
import {ISplitterToken} from "../src/interfaces/internals/ISplitterToken.sol";
import {ICommonStruct} from "../src/interfaces/internals/ICommonStruct.sol";
import "../src/libs/Resources.sol";

import "forge-std/console.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";



contract DeployContext is  StdCheats, StdUtils,Test {
    uint256 public MAX_UINT = uint256(int256(-1));

    address public owner = makeAddr("Owner");
    address public ownerGauge = makeAddr("ownerGauge");
    address public feeTreasury = makeAddr("feeTreasury");
    LendRewardSplitter public splitter;
    // address public gUSDBeaconSdt;
    // address public scvUSDBeaconSdt;
    address public gUSDBeaconCvx;
    address public scvUSDBeaconCvx;
    address public scvUSDBeaconCompounder;
    address public proxyAdmin;

    /// @dev Validate Implementation (false if you don't want to "forge clean" at each modification)
    bool constant IS_VALIDATE_IMPLEM = false;

    function deployBaseContracts() public {
        vm.createSelectFork("mainnet", 20725852);
        //Proxys
        deployProxyAdmin();
        // deployGUSDBeaconSdt();
        // deploySCVUSDBeaconSdt();
        deployGUSDBeaconCvx();
        deploySCVUSDBeaconCvx();
        deployScvUSDCompounder();
        deploySplitterProxy(owner);

        vm.startPrank(owner);
        splitter.toggleZapToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        splitter.toggleZapToken(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
        splitter.toggleZapToken(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        vm.stopPrank();

        //labelizing
        vm.label(address(splitter), "SPLITTER");
        vm.label(address(AddrClassicERC20.TOKEN_CRVUSD), "crvUSD");
        vm.label(address(AddrGlobal.CVX_BOOSTER), "CVX_BOOSTER");
    }

    function deployProxyAdmin() public {
        proxyAdmin = address(new ProxyAdmin(owner));
    }

    function deployGUSDBeaconCvx() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("gUSDCvx.sol:gUSDCvx", opts);
        }
        //deploy
        gUSDBeaconCvx = address(new UpgradeableBeacon(address(new gUSDCvx()), (owner)));
        return gUSDBeaconCvx;
    }

    function deploySCVUSDBeaconCvx() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("scvUSDCvx.sol:scvUSDCvx", opts);
        }
        //deploy
        scvUSDBeaconCvx = address(new UpgradeableBeacon(address(new scvUSDCvx()), (owner)));
        return scvUSDBeaconCvx;
    }

    function deployScvUSDCompounder() public returns (address) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("SplitterTokenComp.sol:SplitterTokenComp", opts);
        }
        //deploy
        scvUSDBeaconCompounder = address(new UpgradeableBeacon(address(new SplitterTokenComp()), (owner)));
        return scvUSDBeaconCompounder;
    }

    function deploySplitterProxy(address ownerToSet) public returns (LendRewardSplitter) {
        if (IS_VALIDATE_IMPLEM) {
            Options memory opts;
            Upgrades.validateImplementation("LendRewardSplitter.sol:LendRewardSplitter", opts);
        }
        //deploy
        splitter = LendRewardSplitter(
            address(
                new TransparentUpgradeableProxy(
                    address(new LendRewardSplitter()),
                    proxyAdmin,
                    abi.encodeCall(LendRewardSplitter.initialize, (ownerToSet, feeTreasury, gUSDBeaconCvx, scvUSDBeaconCvx, scvUSDBeaconCompounder))
                )
            )
        );
        return splitter;
    }

    function _takesGaugeOnwershipAndSetDistributor(ISdtLiquidityGauge _sdtLiquidityGauge) public {
        vm.deal(ownerGauge, 10 ether);
        address admin = _sdtLiquidityGauge.admin();
        uint256 rewardCount = _sdtLiquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            vm.startPrank(ownerGauge);
            IERC20 token = IERC20(_sdtLiquidityGauge.reward_tokens(i));
            token.approve(address(_sdtLiquidityGauge), 0);
            token.approve(address(_sdtLiquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            _sdtLiquidityGauge.set_reward_distributor(address(token), ownerGauge);
            unchecked {
                ++i;
            }
        }
    }

    function _distributeGaugeRewards(ISdtLiquidityGauge _sdtLiquidityGauge, ICommonStruct.TokenAmount[] memory tokenAmounts) public {
        for (uint256 i; i < tokenAmounts.length; ) {
            vm.startPrank(ownerGauge);
            deal(address(tokenAmounts[i].token), ownerGauge, tokenAmounts[i].amount);
            _sdtLiquidityGauge.deposit_reward_token(address(tokenAmounts[i].token), tokenAmounts[i].amount);
            vm.stopPrank();

            unchecked {
                ++i;
            }
        }
        vm.stopPrank();
    }
    struct Transfers{
        IERC20 erc20;
        address from;
        address to;
        uint256 amount;
    }

    struct BalancesChange{
        IERC20 erc20;
        uint256 balFrom;
        uint256 balTo;
        address from;
        address to;
        uint256 amount;
    }

    function createBalancesChange(IERC20 erc20, address from, address to, uint256 amount) public view returns(BalancesChange memory){
        return BalancesChange({
            erc20 : erc20,
            from : from,
            to : to,
            amount : amount,
            balFrom : 0,
            balTo:0
        });
    }



    function getBalances(BalancesChange[] memory balChanges) public view returns(BalancesChange[] memory) {
        for (uint256 index = 0; index < balChanges.length; index++) {
            BalancesChange memory bal = balChanges[index];
            IERC20 erc20 = bal.erc20;
            // Mint 
            if(bal.from == address(0)) {
                bal.balFrom = erc20.totalSupply();
            }
            else {
                bal.balFrom = erc20.balanceOf(bal.from);

            }
            // Burn
            if(bal.to == address(0)){
                bal.balTo = erc20.totalSupply();
            }
            else{
                bal.balTo = erc20.balanceOf(bal.to);
            }
        }
        return balChanges;
    }

    function assertBalanceChanges(BalancesChange[] memory balChanges) public view returns(BalancesChange[] memory) {
        for (uint256 index = 0; index < balChanges.length; index++) {
            BalancesChange memory bal = balChanges[index];
            IERC20 erc20 = bal.erc20;
            // Mint 
            if(bal.from == address(0)) {
                assertEq(erc20.totalSupply() - bal.balFrom, bal.amount);
            }
            else {
                assertEq(bal.balFrom - erc20.balanceOf(bal.from), bal.amount);
            }
            // Burn
            if(bal.to == address(0)){
                assertEq(bal.balTo - erc20.totalSupply(), bal.amount);
            }
            else{
                assertEq(erc20.balanceOf(bal.to) - bal.balTo  , bal.amount);
            }
        }
        return balChanges;
    }



    function assertTransfers(Vm.Log[] memory logss, Transfers[] memory transfersToAssert) public {
        uint256 logsLength = logss.length;
        console.log(logsLength);
        for (uint256 index = 0; index < logss.length; ) {
            uint256 len = logss.length;
            if(len != 1){
                logss[index] = logss[len - 1];
                assembly {
                    // Réduire la taille du tableau de 1
                    mstore(logss, sub(len, 1))
                 }
            }
            else {
                index++;
            }
        }

        // Converts all logs 
        for (uint256 index = 0; index < logss.length; index++) {
            Vm.Log memory logg = logss[index];
            bytes32 key = keccak256(abi.encodePacked(logg.emitter, bytes32ToAddress(logg.topics[1]), bytes32ToAddress(logg.topics[2]), logg.data));
            _tStoreBoolForBytes32(key, true);
        }

        // Verify all expect
        for (uint256 i = 0; i < transfersToAssert.length; i++) {
            Transfers memory t = transfersToAssert[i];
            bytes32 aa = keccak256(abi.encodePacked(t.erc20, t.from, t.to, abi.encode(t.amount)));
            assertEq(_tLoadBoolForBytes32(aa), true, string.concat("Transfer from ", vm.toString(t.from), " to ", vm.toString(t.to), " of amount : ", vm.toString(t.amount), " didn't occur"));
        }


        console.log(logss.length);
        vm.stopPrank();
    }


    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function bytes32ToAddress(bytes32 _bytes32) public view returns(address){
        return address(uint160(uint256(_bytes32)));
    }

    function _tStoreBoolForBytes32(bytes32 location, bool value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tLoadBoolForBytes32(bytes32 location) private view returns (bool value) {
        assembly {
            value := tload(location)
        }
    }
}
