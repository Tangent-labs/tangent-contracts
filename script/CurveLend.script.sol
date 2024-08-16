// SPDX-License-Identifier: UNLICENSED

import "../lib/forge-std/src/Test.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {ICurveLendVault} from "../src/interfaces/ICurveLendVault.sol";
import {IStakeDaoVault} from "../src/interfaces/IStakeDaoVault.sol";
import {ISDLiquidityGauge} from "../src/interfaces/ISDLiquidityGauge.sol";
import {ICrvUSDController} from "../src/interfaces/ICrvUSDController.sol";
import {CsvMaker} from "./CsvMaker.sol";
import {DecimalsString} from "./DecimalsString.sol";
//source :  https://etherscan.io/tx/0x15af2ec72371090dde0da81e7c6c069afb35c259470d57df14f49fad729acfdd

contract CurveLend is Test {
    using DecimalsString for uint;

    struct DepositData {
        uint256 amount;
        uint pricePerShare;
    }

    mapping(address => DepositData[]) deposits;
    uint256 MAX_UINT = uint256(int256(-1));
    mapping(string => address) users;
    string[] userNames = ["alice", "bob", "freddy"];
    uint256 usersLength = 3;

    address TOKEN_CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52; //
    address TOKEN_crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;

    // Vaulted crvUSD
    address CURVE_CRV_VAULT = 0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA; // Vaulted crvUSD
    // Vaulted crvUSD in stake DAO
    address STAKEDAO_CRV_VAULT = 0xfa6D40573082D797CB3cC378c0837fB90eB043e5;

    IStakeDaoVault stakeDaoVault;
    ICurveLendVault curveVault;
    ISDLiquidityGauge gaugeV4;
    ICrvUSDController crvUSDController;

    uint currentDay = 0;

    struct SupplyActionData {
        string user;
        string assetType;
        uint256 pricePershare;
        string action;
        uint256 amountToken;
        uint256 amountLp;
        uint day;
    }
    event SupplyAction(SupplyActionData data);

    SupplyActionData[] actions;
    uint256 actionsLength;

    function init() internal {
        users["alice"] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Hardhat #1
        vm.label(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, "alice");
        users["bob"] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Hardhat #2
        vm.label(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC, "albobice");
        users["freddy"] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Hardhat #3
        vm.label(0x90F79bf6EB2c4f870365E785982E1f101E93b906, "freddy");

        stakeDaoVault = IStakeDaoVault(STAKEDAO_CRV_VAULT);
        gaugeV4 = ISDLiquidityGauge(stakeDaoVault.liquidityGauge());
        curveVault = ICurveLendVault(CURVE_CRV_VAULT);
        crvUSDController = ICrvUSDController(curveVault.controller());

        console.log(stakeDaoVault.token(), curveVault.borrowed_token());
    }

    function travelDay(uint dayToAdd) internal {
        skip(3600 * 24 * dayToAdd);
        currentDay += dayToAdd;
    }

    enum Action {
        deposit,
        withdraw
    }

    function scenario1() internal {
        doAction(Action.deposit, "alice", 5_000 ether, "stableAsset");
        travelDay(10);
        doAction(Action.deposit, "bob", 5_000 ether, "govAsset");
        travelDay(10);
        doAction(Action.deposit, "bob", 3_000 ether, "govAsset");
        travelDay(10);
        doAction(Action.deposit, "alice", 1_000 ether, "stableAsset");
        travelDay(10);
        doAction(Action.withdraw, "bob", 80, "govAsset"); //80%
        travelDay(10);
        doAction(Action.withdraw, "alice", 50, "stableAsset"); //50%
        doAction(Action.deposit, "freddy", 5_000 ether, "stableAsset");
        travelDay(10);
        doAction(Action.withdraw, "alice", 100, "stableAsset"); //100%
        doAction(Action.withdraw, "bob", 100, "govAsset"); //100%
        travelDay(10);
        doAction(Action.withdraw, "freddy", 100, "stableAsset"); //100%

        processLogs();
    }

    function pocTransfer() public {
        address jhon = makeAddr("jhon");
        address jim = makeAddr("jim");
        deal(address(stakeDaoVault), jhon, 1_000 ether);

        vm.startPrank(jhon);
        stakeDaoVault.approve(address(this), 1_000 ether);
        vm.stopPrank();

        uint balanceBefore = stakeDaoVault.balanceOf(jim);
        stakeDaoVault.transferFrom(jhon, jim, 2 ether);
        uint balanceAfter = stakeDaoVault.balanceOf(jim);
        console.log(balanceBefore, balanceAfter);
    }

    function run() public {
        // Fork mainnet.
        vm.createSelectFork("mainnet");

        // init users and contract
        init();

        // Give tokens to the WALLET and Approve
        prepareWallets();

        // Run the scenario
        scenario1();

        // End.
        vm.stopPrank();
    }

    function doAction(
        Action action,
        string memory user,
        uint256 amount,
        string memory assetType
    ) internal {
        if (action == Action.deposit) {
            actionDeposit(user, amount, assetType);
            return;
        }
        if (action == Action.withdraw) {
            actionWithdraw(user, amount, assetType);
            return;
        }
    }

    function actionDeposit(
        string memory user,
        uint256 amount,
        string memory assetType
    ) internal {
        vm.startPrank(users[user]);

        uint256 amountOut = curveVault.deposit(amount);
        //displayState("deposited  curveVault", users[user]);
        stakeDaoVault.deposit(users[user], amountOut, false);
        //displayState("deposited stakeDaoVault", users[user]);
        actions.push(
            SupplyActionData(
                user,
                assetType,
                curveVault.pricePerShare(),
                "deposit",
                amount,
                amountOut,
                currentDay
            )
        );
        actionsLength++;
        displayState(
            string.concat(
                user,
                " deposited ",
                amount.toDecimalString(18, false)
            ),
            users[user]
        );
        vm.stopPrank();
    }

    function actionWithdraw(
        string memory user,
        uint256 percentage,
        string memory assetType
    ) internal {
        require(percentage <= 100);

        vm.startPrank(users[user]);
        uint balanceBefore = IERC20(TOKEN_crvUSD).balanceOf(users[user]);

        uint balance = gaugeV4.balanceOf(users[user]);
        uint amountOutStake = balance;
        if (percentage < 100) {
            amountOutStake = (balance * percentage) / 100;
        }

        stakeDaoVault.withdraw(amountOutStake);
        uint amountToWithdrawFromCurve = curveVault.maxWithdraw(users[user]);
        curveVault.withdraw(amountToWithdrawFromCurve);

        uint balanceAfter = IERC20(TOKEN_crvUSD).balanceOf(users[user]);

        // displayBalance(users[user]);
        actions.push(
            SupplyActionData(
                user,
                assetType,
                curveVault.pricePerShare(),
                "withdraw",
                balanceAfter - balanceBefore,
                amountOutStake,
                currentDay
            )
        );
        actionsLength++;
        displayState(
            string.concat(
                user,
                " withdraw ",
                (balanceAfter - balanceBefore).toDecimalString(18, false)
            ),
            users[user]
        );
        vm.stopPrank();
    }

    function processLogs() internal {
        /*
            Action.deposit, "alice", 5_000 ether, "stableAsset"
            */
        string memory path = "./output/write_file.csv";
        CsvMaker csv = new CsvMaker(path);
        csv.writeLine(
            "user;asset-type;pricePerShare;action;amountToken;amountLp;diffDay"
        );
        for (uint256 i; i < actionsLength; i++) {
            csv.addToLine(actions[i].user);
            csv.addToLine(actions[i].assetType);
            csv.addToLine(actions[i].pricePershare.toDecimalString(18, false));
            csv.addToLine(actions[i].action);
            csv.addToLine(actions[i].amountToken.toDecimalString(18, false));
            csv.addToLine(actions[i].amountLp.toDecimalString(18, false));
            csv.addToLine(actions[i].day);
            csv.writeCurrentLine();
        }
    }

    function displayBalance(address wallet) internal view {
        console.log(
            "stakeDaoVault balanceOf ",
            IERC20(address(gaugeV4)).balanceOf(wallet)
        );
        console.log("curveVault balanceOf ", curveVault.balanceOf(wallet));
        console.log("TOKEN_crvUSD", IERC20(TOKEN_crvUSD).balanceOf(wallet));
        console.log("TOKEN_CRV", IERC20(TOKEN_CRV).balanceOf(wallet));
    }

    function displayState(string memory action, address wallet) internal view {
        console.log(
            string.concat(
                "----   ",
                action,
                "    -----------------------------------"
            )
        );
        // displayBalance(wallet);
    }

    function prepareWallets() internal {
        for (uint i = 0; i < usersLength; i++) {
            address wallet = users[userNames[i]];
            vm.startPrank(wallet);

            vm.deal(wallet, 1_000 ether);

            // For supply
            deal(TOKEN_crvUSD, wallet, 100_000 ether);
            IERC20(TOKEN_crvUSD).approve(address(curveVault), MAX_UINT);
            IERC20(CURVE_CRV_VAULT).approve(address(stakeDaoVault), MAX_UINT);

            // For create LOAN( Borrow)
            deal(TOKEN_CRV, wallet, 100_000 ether);
            IERC20(TOKEN_CRV).approve(address(crvUSDController), MAX_UINT);
            vm.stopPrank();
        }

        // Suplier
        // vm.deal(WALLET, 1_000 ether);
        // deal(CURVE_CRV_VAULT, WALLET, 10_000 ether);
        // deal(TOKEN_CRV, WALLET, 100_000 ether);
        // deal(TOKEN_crvUSD, WALLET, 10_000 ether);
        // // For Deposit  on stakeDAO strategy.
        // IERC20(CURVE_CRV_VAULT).approve(address(stakeDaoVault), MAX_UINT);

        // // For Deposit (Supply).
        // IERC20(TOKEN_crvUSD).approve(address(curveVault), MAX_UINT);

        // Borrower
        // vm.deal(WALLET_BOROWER, 1_000 ether);
        // deal(TOKEN_CRV, WALLET_BOROWER, 10_000 ether);
        // IERC20(TOKEN_CRV).approve(address(curveVault), MAX_UINT);
    }
}
