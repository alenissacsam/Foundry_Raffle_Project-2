//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/MockLinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    /*    Chainlink VRF Coordinator V2.5 Mock constants */
    uint96 public constant BASE_FEE = 0.25 ether;
    uint96 public constant GAS_PRICE = 0.0001 ether;
    int256 public constant WEI_PER_LINK = 4e18;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig_ChainNotSupported(uint256 chainID);

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainID => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getActiveNetworkConfig(
        uint256 chainID
    ) public returns (NetworkConfig memory) {
        if (chainID == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (chainID == SEPOLIA_CHAIN_ID) {
            return networkConfigs[SEPOLIA_CHAIN_ID];
        } else {
            revert HelperConfig_ChainNotSupported(chainID);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getActiveNetworkConfig(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30 seconds,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 48766142336396036523125430336803919608337516992867669877692698565702455163445,
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        /* Deploy Mock */
        vm.startBroadcast();
        LinkToken link = new LinkToken();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE,
            WEI_PER_LINK
        );
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(link)
        });
        return activeNetworkConfig;
    }
}
