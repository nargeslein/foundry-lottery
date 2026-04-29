//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {
    CreateSubscription,
    FundSubscription,
    AddConsumer
} from "./Interactions.s.sol";

/**
 * @author Narges H.
 */
contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            uint256 subId = createSubscription.createSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.deployerKey
            );
            networkConfig.subscriptionId = subId;

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                networkConfig.vrfCoordinator,
                subId,
                networkConfig.link,
                networkConfig.deployerKey
            );
        }

        vm.startBroadcast(networkConfig.deployerKey);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.deployerKey
        );

        return (raffle, helperConfig);
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        return run();
    }
}
