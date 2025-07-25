//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    event RaffleEntered(address indexed player);
    event WinnerSelected(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 public constant STARTING_BALANCE = 1 ether;

    address public PLAYER = makeAddr("player1");
    address public PLAYER2 = makeAddr("player2");
    address public PLAYER3 = makeAddr("player3");

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    modifier RaffleEntering() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            console.log("Skipping test on Sepolia as it is not supported in this test environment.");
            return;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(PLAYER2, STARTING_BALANCE);
        vm.deal(PLAYER3, STARTING_BALANCE);
    }

    function testRaffleInitialization() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assertEq(raffle.getInterval(), interval);
        assertEq(raffle.getEntryFee(), entranceFee);
        assertEq(raffle.getVrfCoordinator(), vrfCoordinator);
        assertEq(raffle.getGasLane(), gasLane);
        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit);
    }

    function testEntryRaffle() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        assertEq(raffle.getPlayers(0), PLAYER);
        assertEq(raffle.getPlayersCount(), 1);
        assertEq(address(raffle).balance, entranceFee);
    }

    function testMultipleEntries() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER3);
        raffle.enterRaffle{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 3);
        assertEq(address(raffle).balance, entranceFee * 3);

        assertEq(raffle.getPlayers(0), PLAYER);
        assertEq(raffle.getPlayers(1), PLAYER2);
        assertEq(raffle.getPlayers(2), PLAYER3);
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function testwhenPlayerNotPay() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_SendMoreETHToEnterRaffle.selector);
        raffle.enterRaffle();

        assertEq(raffle.getPlayersCount(), 0);
        assertEq(address(raffle).balance, 0);
    }

    function testWhenRaffleIsCalculating() public RaffleEntering {
        console.log("Raffle state after performing upkeep:", uint256(raffle.getRaffleState()));
        vm.prank(PLAYER);
        raffle.performUpkeep("");
        console.log("Raffle state after performing upkeep:", uint256(raffle.getRaffleState()));
        vm.prank(PLAYER2);
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepWhenNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepWhenRaffleNotOpen() public RaffleEntering {
        vm.prank(PLAYER);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnTrue() public RaffleEntering {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeepWhenUpKeepReturnFalse() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpKeepNotNeeded.selector,
                address(raffle).balance,
                raffle.getPlayersCount(),
                uint256(raffle.getRaffleState())
            )
        );
        raffle.performUpkeep("");
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepEmits() public RaffleEntering {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assert(uint256(entries[1].topics[1]) > 0);
    }

    /*//////////////////////////////////////////////////////////////
                          FULLFILL_RANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerfomUpKeep(uint256 randomReqId)
        public
        RaffleEntering
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomReqId, address(raffle));
    }

    /*//////////////////////////////////////////////////////////////
                            END_TO_END_TEST
    //////////////////////////////////////////////////////////////*/

    function testEndToEnd() public RaffleEntering skipFork {
        /* Adding 3 more player */

        uint256 additionalPlayers = 3;
        for (uint256 i = 0; i < additionalPlayers; i++) {
            address newPlayer = address(uint160(i + 1));
            hoax(newPlayer, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 requestId = uint256(entries[1].topics[1]);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getRecentWinner().balance == STARTING_BALANCE + 3 * entranceFee);
        assert(raffle.getLastTimeStamp() > startingTimeStamp);
        assert(raffle.getPlayersCount() == 0);
        assert(address(raffle).balance == 0);
    }
}
