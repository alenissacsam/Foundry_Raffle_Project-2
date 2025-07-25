//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/MockLinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    // This script is used to create a subscription for Chainlink VRF.
    function run() public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        return (createSubscription(vrfCoordinator, account), vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256) {
        console.log("Creating subscription on VRF Coordinator: %s", vrfCoordinator);

        vm.startBroadcast(account);

        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();

        vm.stopBroadcast();

        console.log("Subscription created with ID: %s", subscriptionId);

        return subscriptionId;
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 100 ether;

    function run() external {
        funsSubscriptionUsingConfig();
    }

    function funsSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        if (subscriptionId == 0) {
            console.log("Subscription ID is not set. Running Subscription script first.");

            CreateSubscription createSubscription = new CreateSubscription();

            subscriptionId = createSubscription.createSubscription(vrfCoordinator, helperConfig.getConfig().account);
        }
        fundSubscription(vrfCoordinator, subscriptionId, link, helperConfig.getConfig().account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link, address account) public {
        console.log("Funding subscription %s on VRF Coordinator: %s", subscriptionId, vrfCoordinator);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
        console.log("Subscription %s funded with %s LINK", subscriptionId, FUND_AMOUNT);
    }
}

contract AddConsumer is Script, CodeConstants {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, helperConfig.getConfig().account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
        console.log(
            "Added consumer %s to subscription %s on VRF Coordinator: %s", contractToAddToVrf, subId, vrfCoordinator
        );
    }
}
