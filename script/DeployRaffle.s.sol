// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

pragma solidity 0.8.19;

contract DeployRaffle is Script {
     bytes32 constant GAS_LANE = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c; 
    function run() external returns (Raffle, HelperConfig) {
              
                
        HelperConfig helperConfig = new HelperConfig(); 
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            // Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
        }

        vm.startBroadcast();
        // uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callBackGasLimit
        Raffle raffle = new Raffle(entranceFee,  interval,  vrfCoordinator,  GAS_LANE,  subscriptionId, callBackGasLimit);
        vm.stopBroadcast();

        // after Raffle has been deployed we need to add consumer for this new raffles contract
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId, deployerKey);

        return (raffle, helperConfig);
    }
}
