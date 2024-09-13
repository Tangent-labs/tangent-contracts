import "forge-std/Test.sol";
import "forge-std/console.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import "./LendSplitterHandler.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";

contract IntroInvariantTest is Test {
    LendRewardSplitter private lendSplitter;
    LendSplitterHandler private lendSplitterHandler;
    LendRewardSplitterTestCommon private testCommon;

    ICurveLendSplitterToken private gUSD;
    ICurveLendSplitterToken private scvUSD;

    address owner = makeAddr("owner");
    address usr1 = makeAddr("User1");
    address usr2 = makeAddr("User2");
    address usr3 = makeAddr("User3");
    address usr4 = makeAddr("User4");
    address usr5 = makeAddr("User5");
    address usr6 = makeAddr("User6");

    function setUp() public {
        vm.createSelectFork("mainnet", 20725852);

        testCommon = new LendRewardSplitterTestCommon();

        vm.startPrank(owner);
        testCommon.deployProxyAdmin();
        testCommon.deployGUSDBeaconSdt();
        testCommon.deploySCVUSDBeaconSdt();
        testCommon.deployGUSDBeaconCvx();
        testCommon.deploySCVUSDBeaconCvx();
        lendSplitter = LendRewardSplitter(testCommon.deploySplitterProxy(owner));
        lendSplitter.createCvxMarket(325);
        lendSplitterHandler = new LendSplitterHandler(lendSplitter);

        gUSD = lendSplitter.gUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);
        scvUSD = lendSplitter.scvUSDCvxPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

        vm.stopPrank();

        targetSender(usr1);
        targetSender(usr2);
        targetSender(usr3);
        targetSender(usr4);
        targetSender(usr5);
        targetSender(usr6);

        targetContract(address(lendSplitterHandler));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = LendSplitterHandler.depositCvx.selector;
        selectors[1] = LendSplitterHandler.withdrawCvx.selector;
        targetSelector(FuzzSelector({addr: address(lendSplitterHandler), selectors: selectors}));
    }

    function invariant_total_supply_equals_sums_of_balances() public {
        assertEq(lendSplitterHandler.sumBalanceOfGUSD(), gUSD.totalSupply());
        assertEq(lendSplitterHandler.sumBalanceOfscvUSD(), scvUSD.totalSupply());
    }
}
