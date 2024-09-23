import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";

import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";

contract LendRewardSplitterCreateMarket is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    address owner = makeAddr("Owner");
    address randomUser = makeAddr("RandomUser");

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_revertWhen_CreateMarketWithRandomUser() external {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        vm.prank(randomUser);
        splitter.createSdtMarket(AddrSdtVaults.CRVUSD_CRV);
    }

    function test_revertWhen_CreateMarketAlreadyExistent() external {
        vm.expectRevert(bytes("MARKET_ALREADY_EXIST"));
        vm.prank(owner);
        splitter.createSdtMarket(AddrSdtVaults.CRVUSD_CRV);
    }

    function test_revertWhen_CreateMarketWithWrongVault() external {
        vm.expectRevert();
        vm.prank(owner);
        splitter.createSdtMarket(IStakeDaoVault(address(AddrClassicERC20.TOKEN_SDT)));
    }

    function test_CreateMarketAndVerifyDatas() external {
        vm.prank(owner);
        splitter.createSdtMarket(AddrSdtVaults.CRVUSD_LEVERAGE_WETH);
        assertEq(address(splitter.sdtVaultPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)), address(AddrSdtVaults.CRVUSD_LEVERAGE_WETH));
        assertEq(address(splitter.lentAssetPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)), address(AddrClassicERC20.TOKEN_CRVUSD));
        assertEq(address(splitter.sdtGaugePerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)), address(AddrSdtGauges.CRVUSD_LEVERAGE_WETH));
        assumeNotZeroAddress(address(splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)));
        assumeNotZeroAddress(address(splitter.scvUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_LEVERAGE_WETH)));
    }
}
