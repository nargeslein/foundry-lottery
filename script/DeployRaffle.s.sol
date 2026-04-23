//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() public {}
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local -> deploy mocks
        //sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();
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
        return (raffle, helperConfig);
    }
}
