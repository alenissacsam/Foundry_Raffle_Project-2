// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title A sample Raffle contract
 * @author @alenissacsam
 * @notice This is a simple contract for educational purposes only.
 * @dev Implements Chainlink VRFv2.5
 */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Raffle_SendMoreETHToEnterRaffle();
    error Raffle_TransferError();
    error Raffle_RaffleNotOpen();
    error Raffle_NoPlayersEntered();
    error Raffle_RaffleNotClosed();

    error Raffle_UpKeepNotNeeded(uint256 Balance, uint256 Players, RaffleState raffleState);

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval; // @dev The duration of the lottery in seconds
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;
    mapping(address => uint256) funderToAmountFunded;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RaffleEntered(address indexed player);
    event WinnerSelected(address indexed winner);
    event RequestId(uint256 indexed requestId);

    constructor(
        uint256 _entryFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = _entryFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //Checks
        if (msg.value < i_entryFee) {
            revert Raffle_SendMoreETHToEnterRaffle();
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle_RaffleNotOpen();
        }
        //Effects
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() private {
        //Checks
        if (s_players.length == 0) {
            revert Raffle_NoPlayersEntered();
        }
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle_RaffleNotClosed();
        }

        //Effects
        s_raffleState = RaffleState.CALCULATING;
        //Interactions
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        emit RequestId(requestId);
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal virtual override {
        //Checks
        //Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerSelected(s_recentWinner);

        //Interactions
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        // require(success, "Transfer failed");
        if (!success) {
            revert Raffle_TransferError();
        }
    }

    /*//////////////////////////////////////////////////////////////
                     CHAINLINK AUTOMATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpKeepNotNeeded(address(this).balance, s_players.length, s_raffleState);
        }
        pickWinner();
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getVrfCoordinator() external view returns (address) {
        return address(s_vrfCoordinator);
    }

    function getGasLane() external view returns (bytes32) {
        return i_keyHash;
    }

    function getSubscriptionId() external view returns (uint256) {
        return i_subscriptionId;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayers(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }
}
