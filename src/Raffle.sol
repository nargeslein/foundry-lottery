// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.19; //version used in course

/**
 * @title A sample Raffle contract
 * @author Narges H.
 * @notice This contract is for creating a sample raffle as part of the Chainlink course
 * @dev implements Chainlink VRFv2.5
 */
contract Raffle {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // Enter the raffle
    }

    function pickWinner() public {}

    /** Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
