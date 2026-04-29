//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {
    VRFCoordinatorV2PlusMock
} from "../test/mocks/VRFCoordinatorV2PlusMock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @author Narges H.
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        return createSubscription(config.vrfCoordinator, config.deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint256) {
        console2.log("Creating subscription on chain id:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subId = VRFCoordinatorV2PlusMock(vrfCoordinator)
            .createSubscription();
        console2.log("Subscription created with id:", subId);
        vm.stopBroadcast();
        console2.log("Your subscription id is:", subId);
        console2.log(
            "Please update your HelperConfig.s.sol file with this subscription id to fund it and add consumers to it."
        );
        return subId;
    }

    function run() external returns (uint256) {
        return createSubscriptionUsingConfig();
    }
}

/**
 * @author Narges H.
 */
contract FundSubscription is Script, CodeConstants {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        uint256 subscriptionId = config.subscriptionId;
        address linkToken = config.link;
        uint256 deployerKey = config.deployerKey;

        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            subscriptionId = createSub.createSubscription(
                vrfCoordinator,
                deployerKey
            );
            console2.log(
                "New SubId Created! ",
                subscriptionId,
                "VRF Address: ",
                vrfCoordinator
            );
        }

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        uint256 deployerKey
    ) public {
        console2.log("Funding subscription: ", subscriptionId);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On chainId: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2PlusMock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
    function run() external {
        fundSubscriptionUsingConfig();
    }
}

/**
 * @author Narges H.
 */
contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint256 subscriptionId,
        uint256 deployerKey
    ) public {
        console2.log("Adding consumer contract: ", raffle);
        console2.log("Using VRFCoordinator: ", vrfCoordinator);
        console2.log("On chain id: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2PlusMock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        addConsumer(
            raffle,
            config.vrfCoordinator,
            config.subscriptionId,
            config.deployerKey
        );
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "MyContract",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
