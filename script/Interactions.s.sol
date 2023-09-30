// SPDX-License-Identifier: MIT

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

pragma solidity 0.8.19;

contract CreateSubscription is Script {

    function createSubscriptionUsingConfig()  public returns(uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,,,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns(uint64) {
        console.log("creating subscription on chain id :" , block.chainid);
        vm.startBroadcast(deployerKey);
        // we run the createSubscription function from inside the mock
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("your Sub Id is : ", subId);
        return(subId);
    }

    function run() external returns(uint64) {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
         HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,uint64 subId,,address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address link, uint256 deployerKey) public {
        console.log("Fund subscription : ", subId);
        console.log("On vrfCoordinator : ", vrfCoordinator);
        console.log("Using Chain id : ", block.chainid);
        if (block.chainid==31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffle);
    }

    function addConsumerUsingConfig(address raffle) public {
          HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,uint64 subId,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId, deployerKey);
    }

    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKey) public {
        console.log("Adding Consumer contract Raffle : ", raffle);
        console.log("Adding consumer to subscription : ", subId);
        console.log("On vrfCoordinator : ", vrfCoordinator);
        console.log("Using Chain id : ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
        
    }
}