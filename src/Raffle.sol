// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {
    VRFConsumerBaseV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

import {
    VRFV2PlusClient
} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {
    AutomationCompatibleInterface
} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract
// Inside Contract:
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
/**
 * @title A sample Raffle contract
 * @author Narges H.
 * @notice This contract is for creating a sample raffle as part of the Chainlink course
 * @dev implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error Raffle__NotEnoughETHEntered();
    error Raffle__TimeHasNotPassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private iInterval;
    bytes32 private immutable I_KEY_HASH;
    uint64 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;

    address payable[] private sPlayers;
    uint256 private sLastTimeStamp;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        I_KEY_HASH = gasLane;
        iInterval = interval;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_ENTRANCE_FEE = entranceFee;
        sRaffleState = RaffleState.OPEN;
        sLastTimeStamp = block.timestamp;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;
    }

    function enterRaffle() public payable {
        // // Enter the raffle
        // require(
        //     msg.value >= i_entranceFee,
        //     "Not enough ETH to enter the raffle"
        // );
        if (msg.value < I_ENTRANCE_FEE) revert Raffle__NotEnoughETHEntered();
        if (sRaffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        sPlayers.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev Function that the Chainlink Keeper nodes call to see if the lottery is ready to end. They look for the following conditions:
     * 1. Our time interval should have passed.
     * 2. The lottery should have at least 1 player, and have some ETH.
     * 3. Our subscription is funded with LINK.     
     @return upkeepNeeded This is a boolean to indicate whether the upkeep is needed or not
     @return performData This is the data we can use to specify any extra information about the upkeep, we don't need it in this example, so we'll leave it blank
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = (sRaffleState == RaffleState.OPEN);
        bool timePassed = ((block.timestamp - sLastTimeStamp) > iInterval);
        bool hasPlayers = (sPlayers.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                sPlayers.length,
                uint256(sRaffleState)
            );
        }

        if (block.timestamp - sLastTimeStamp < iInterval) {
            revert Raffle__TimeHasNotPassed();
        }

        sRaffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory str = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: I_KEY_HASH,
                subId: I_SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: I_CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        s_vrfCoordinator.requestRandomWords(str);
    }

    /** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    //Checks, Effects, Interactions pattern is used in the fulfillRandomWords function to prevent reentrancy attacks
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        //CHECKS

        //EFFECTS
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];
        sRecentWinner = recentWinner;

        sRaffleState = RaffleState.OPEN;
        sPlayers = new address payable[](0);
        sLastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        //INTERACTIONS
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // Reset the raffle
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
}
