// SPDX-License-Identifier: MIT


import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

pragma solidity 0.8.19;

contract HelperConfig is Script{
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval; 
        address vrfCoordinator;
        uint64 subscriptionId;
        uint32 callBackGasLimit;
        address link;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig ;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory sepoliaNetworkConfig){
        sepoliaNetworkConfig = NetworkConfig({
            entranceFee : 0.01 ether,
            interval : 30,
            vrfCoordinator : 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            subscriptionId : uint64(vm.envUint("SEPOLIA_SUBSCRIPTION_ID")),
            callBackGasLimit : 500000, // 500.000 gas
            link : 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey : vm.envUint("PRIVATE_KEY_SEPOLIA")
        });
    }

        function getOrCreateAnvilEthConfig() public  returns(NetworkConfig memory){
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        
        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9; // 1 gwei

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        
        return NetworkConfig({
            entranceFee : 0.01 ether,
            interval : 30,
            vrfCoordinator : address(vrfCoordinatorV2Mock),
            subscriptionId : 0, // our script will add this
            callBackGasLimit : 500000, // 500.000 gas
            link: address(linkToken),
            deployerKey : vm.envUint("PRIVATE_KEY_LOCAL")
        });
    }
}