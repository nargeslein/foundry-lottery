// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {
    CreateSubscription,
    FundSubscription,
    AddConsumer
} from "../../script/Interactions.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {LinkToken, ERC677Receiver} from "../mocks/LinkToken.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract LinkFundingReceiver is ERC677Receiver {
    address public token;
    address public sender;
    uint256 public amount;
    bytes public data;

    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes memory _data
    ) external override {
        token = msg.sender;
        sender = _sender;
        amount = _value;
        data = _data;
    }
}

contract InteractionsTest is Test, CodeConstants {
    VRFCoordinatorV2_5Mock private vrfCoordinator;
    CreateSubscription private createSubscription;
    FundSubscription private fundSubscription;
    AddConsumer private addConsumer;

    address private raffle = makeAddr("raffle");
    string private constant BROADCAST_DIR =
        "broadcast/InteractionsTest/31337";
    string private constant BROADCAST_FILE =
        "broadcast/InteractionsTest/31337/run-latest.json";

    function setUp() external {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
    }

    function testCreateSubscriptionCreatesAnActiveSubscription() public {
        (uint256 subId, address returnedCoordinator) = createSubscription
            .createSubscription(address(vrfCoordinator));

        (
            uint96 balance,
            uint96 nativeBalance,
            uint64 requestCount,
            address owner,
            address[] memory consumers
        ) = vrfCoordinator.getSubscription(subId);

        assertEq(returnedCoordinator, address(vrfCoordinator));
        assertEq(balance, 0);
        assertEq(nativeBalance, 0);
        assertEq(requestCount, 0);
        assertTrue(owner != address(0));
        assertEq(consumers.length, 0);
    }

    function testFundSubscriptionFundsAnExistingLocalSubscription() public {
        (uint256 subId, ) = createSubscription.createSubscription(
            address(vrfCoordinator)
        );

        fundSubscription.fundSubscription(
            address(vrfCoordinator),
            subId,
            address(0)
        );

        (uint96 balance, , , , ) = vrfCoordinator.getSubscription(subId);

        assertEq(balance, fundSubscription.FUND_AMOUNT());
    }

    function testFundSubscriptionTransfersLinkOnNonLocalChains() public {
        uint256 sepoliaSubscriptionId = 1;
        LinkToken linkToken = new LinkToken();
        LinkFundingReceiver receiver = new LinkFundingReceiver();
        linkToken.mint(DEFAULT_SENDER, fundSubscription.FUND_AMOUNT());

        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        fundSubscription.fundSubscription(
            address(receiver),
            sepoliaSubscriptionId,
            address(linkToken)
        );

        assertEq(
            linkToken.balanceOf(address(receiver)),
            fundSubscription.FUND_AMOUNT()
        );
        assertEq(receiver.token(), address(linkToken));
        assertEq(receiver.sender(), DEFAULT_SENDER);
        assertEq(receiver.amount(), fundSubscription.FUND_AMOUNT());
        assertEq(
            keccak256(receiver.data()),
            keccak256(abi.encode(sepoliaSubscriptionId))
        );
    }

    function testFundSubscriptionRunUsesConfigPath() public {
        fundSubscription.run();
    }

    function testAddConsumerAddsRaffleToSubscription() public {
        (uint256 subId, ) = createSubscription.createSubscription(
            address(vrfCoordinator)
        );

        addConsumer.addConsumer(raffle, address(vrfCoordinator), subId);

        (, , , , address[] memory consumers) = vrfCoordinator.getSubscription(
            subId
        );

        assertTrue(vrfCoordinator.consumerIsAdded(subId, raffle));
        assertEq(consumers.length, 1);
        assertEq(consumers[0], raffle);
    }

    function testFundSubscriptionUsingConfigCreatesAndFundsLocalSubscription()
        public
    {
        fundSubscription.fundSubscriptionUsingConfig();
    }

    function testCreateSubscriptionRunUsesConfigPath() public {
        (uint256 subId, address returnedCoordinator) = createSubscription.run();

        assertTrue(subId != 0);
        assertTrue(returnedCoordinator != address(0));
    }

    function testCreateSubscriptionUsingConfigCreatesLocalSubscription()
        public
    {
        (uint256 subId, address returnedCoordinator) = createSubscription
            .createSubscriptionUsingConfig();

        assertTrue(subId != 0);
        assertTrue(returnedCoordinator != address(0));
    }

    function testAddConsumerUsingConfigRevertsWhenConfigHasNoSubscription()
        public
    {
        vm.expectRevert();
        addConsumer.addConsumerUsingConfig(raffle);
    }

    function testAddConsumerRunFindsDeploymentBeforeConfigRevert() public {
        vm.createDir(BROADCAST_DIR, true);
        vm.writeFile(
            BROADCAST_FILE,
            string.concat(
                '{"timestamp":1,"transactions":[{"contractName":"MyContract",',
                '"contractAddress":"',
                vm.toString(raffle),
                '"}]}'
            )
        );

        try addConsumer.run() {
            fail("expected addConsumer.run to revert");
        } catch {}

        vm.removeFile(BROADCAST_FILE);
        vm.removeDir("broadcast/InteractionsTest", true);
    }
}
