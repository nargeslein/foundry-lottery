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
    VRFCoordinatorV2PlusMock
} from "../mocks/VRFCoordinatorV2PlusMock.sol";

/**
 * @author Narges H.
 */
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

/**
 * @author Narges H.
 */
contract InteractionsTest is Test, CodeConstants {
    VRFCoordinatorV2PlusMock private vrfCoordinator;
    CreateSubscription private createSubscription;
    FundSubscription private fundSubscription;
    AddConsumer private addConsumer;

    address private raffle = makeAddr("raffle");
    string private constant BROADCAST_DIR =
        "broadcast/InteractionsTest/31337";
    string private constant BROADCAST_FILE =
        "broadcast/InteractionsTest/31337/run-latest.json";

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function setUp() external {
        vrfCoordinator = new VRFCoordinatorV2PlusMock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK
        );
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
    }

    function testCreateSubscriptionCreatesAnActiveSubscription() public skipFork {
        uint256 subId = createSubscription.createSubscription(
            address(vrfCoordinator),
            DEFAULT_ANVIL_KEY
        );

        (
            uint96 balance,
            uint96 nativeBalance,
            uint64 requestCount,
            address owner,
            address[] memory consumers
        ) = vrfCoordinator.getSubscription(subId);

        assertEq(balance, 0);
        assertEq(nativeBalance, 0);
        assertEq(requestCount, 0);
        assertEq(owner, vm.addr(DEFAULT_ANVIL_KEY));
        assertEq(consumers.length, 0);
    }

    function testFundSubscriptionFundsAnExistingLocalSubscription() public skipFork {
        uint256 subId = createSubscription.createSubscription(
            address(vrfCoordinator),
            DEFAULT_ANVIL_KEY
        );

        fundSubscription.fundSubscription(
            address(vrfCoordinator),
            subId,
            address(0),
            DEFAULT_ANVIL_KEY
        );

        (uint96 balance, , , , ) = vrfCoordinator.getSubscription(subId);

        assertEq(balance, fundSubscription.FUND_AMOUNT());
    }

    function testFundSubscriptionTransfersLinkOnNonLocalChains() public skipFork {
        uint256 sepoliaSubscriptionId = 1;
        LinkToken linkToken = new LinkToken();
        LinkFundingReceiver receiver = new LinkFundingReceiver();
        address deployer = vm.addr(DEFAULT_ANVIL_KEY);
        linkToken.mint(deployer, fundSubscription.FUND_AMOUNT());

        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        fundSubscription.fundSubscription(
            address(receiver),
            sepoliaSubscriptionId,
            address(linkToken),
            DEFAULT_ANVIL_KEY
        );

        assertEq(
            linkToken.balanceOf(address(receiver)),
            fundSubscription.FUND_AMOUNT()
        );
        assertEq(receiver.token(), address(linkToken));
        assertEq(receiver.sender(), deployer);
        assertEq(receiver.amount(), fundSubscription.FUND_AMOUNT());
        assertEq(
            keccak256(receiver.data()),
            keccak256(abi.encode(sepoliaSubscriptionId))
        );
    }

    function testFundSubscriptionRunUsesConfigPath() public skipFork {
        fundSubscription.run();
    }

    function testAddConsumerAddsRaffleToSubscription() public skipFork {
        uint256 subId = createSubscription.createSubscription(
            address(vrfCoordinator),
            DEFAULT_ANVIL_KEY
        );

        addConsumer.addConsumer(
            raffle,
            address(vrfCoordinator),
            subId,
            DEFAULT_ANVIL_KEY
        );

        (, , , , address[] memory consumers) = vrfCoordinator.getSubscription(
            subId
        );

        assertTrue(vrfCoordinator.consumerIsAdded(subId, raffle));
        assertEq(consumers.length, 1);
        assertEq(consumers[0], raffle);
    }

    function testFundSubscriptionUsingConfigCreatesAndFundsLocalSubscription()
        public
        skipFork
    {
        fundSubscription.fundSubscriptionUsingConfig();
    }

    function testCreateSubscriptionRunUsesConfigPath() public skipFork {
        uint256 subId = createSubscription.run();

        assertTrue(subId != 0);
    }

    function testCreateSubscriptionUsingConfigCreatesLocalSubscription()
        public
        skipFork
    {
        uint256 subId = createSubscription.createSubscriptionUsingConfig();

        assertTrue(subId != 0);
    }

    function testAddConsumerUsingConfigRevertsWhenConfigHasNoSubscription()
        public
        skipFork
    {
        vm.expectRevert();
        addConsumer.addConsumerUsingConfig(raffle);
    }

    function testAddConsumerRunFindsDeploymentBeforeConfigRevert() public skipFork {
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
