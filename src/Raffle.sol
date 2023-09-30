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

// SPDX-License-Identifier: MIT

/**
 * @title Sample Raffle Contract
 * @author saga
 * @notice Thisis for creating a sample raffle
 * @dev Implements Chainlink VRF
 */

pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface  {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__upkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    //** Typed Declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    //** State Variables */
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 3;

    uint256 private immutable i_entranceFee;
    // @dev duration of the lottery in seconds
    uint256 private immutable i_interval;
    // @dev the contract address of the VRFCoordinator depending on the chain this contract is deployed to
    VRFCoordinatorV2Interface immutable i_vrfCoordinator;
    // @dev keyhash for the gas lane that is dpendent on the chain being used like the coordinator above
    bytes32 immutable i_gasLane;
    // @dev the subscription id to our own subscription in chainlink
    uint64 immutable i_subscriptionId;
    // @dev the limit of the gas amount during the second call to request the random number
    uint32 immutable i_callBackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**
     * Events
     */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(bytes memory /* checkData */ ) public view returns (bool upkeepNeeded, bytes memory) 
    /**
     * performData
     */
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

     function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;
        // @dev Chainlink VRF to choose a winner. A 2 step proccess. The first step is to request an RNG and the second step is once we receive the random number to pick a winner
        // @dev Below directly copied from docs.chainlink.com
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // @dev gas lane
            i_subscriptionId, // @dev the id of the subscription id
            REQUEST_CONFIRMATIONS, // @dev nr of confirmations before the random word is read
            i_callBackGasLimit, // @dev to make sure we dont overspend during the second transaction
            NUM_WORDS // number of random numbers
        );
         emit RequestedRaffleWinner(requestId);
    }

    //** CEI Style -> Checks -> Effects -> Interactions */

    function fulfillRandomWords(uint256, /*_requestId */ uint256[] memory _randomWords) internal override {
        // Checks
        //Effects
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        // Interactions
        emit PickedWinner(winner);
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 player) external view returns(address) {
        return s_players[player];
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }
}
