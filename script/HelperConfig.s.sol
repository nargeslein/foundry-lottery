//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; //version used in course
import {Script} from "forge-std/Script.sol";
import {
    VRFCoordinatorV2PlusMock
} from "../test/mocks/VRFCoordinatorV2PlusMock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

/**
 * @author Narges H.
 */
abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

/**
 * @author Narges H.
 */
contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }
    error HelperConfig__InvalidChainId();

    NetworkConfig public localNetworkConfig;

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: vm.envUint("SEPOLIA_SUBSCRIPTION_ID"),
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
        return sepoliaConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network localNetworkConfig
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        // Deploy mocks if we are on anvil
        vm.startBroadcast(DEFAULT_ANVIL_KEY);
        VRFCoordinatorV2PlusMock vrfCoordinatorMock = new VRFCoordinatorV2PlusMock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            deployerKey: DEFAULT_ANVIL_KEY
        });
        return localNetworkConfig;
    }
}
