//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DeployRaffle is Script {
    function run() public {}
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local -> deploy mocks
        //sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 subId, address vrfCoordinator) = createSubscription
                .createSubscription(networkConfig.vrfCoordinator);
            networkConfig.subscriptionId = subId;
            networkConfig.vrfCoordinator = vrfCoordinator;
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.subscriptionId,
            networkConfig.keyHash,
            networkConfig.interval,
            networkConfig.entranceFee,
            networkConfig.callbackGasLimit,
            networkConfig.vrfCoordinator
        );
        vm.stopBroadcast();
        // If we deployed a mock, we need to add the raffle contract as a consumer
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator).addConsumer(
            networkConfig.subscriptionId,
            address(raffle)
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}
