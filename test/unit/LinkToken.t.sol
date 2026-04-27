// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {LinkToken, ERC677Receiver} from "../mocks/LinkToken.sol";

contract LinkTokenReceiver is ERC677Receiver {
    address public tokenCaller;
    address public originalSender;
    uint256 public amount;
    bytes public data;
    bool public shouldRevert;

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function onTokenTransfer(
        address _sender,
        uint256 _value,
        bytes memory _data
    ) external override {
        if (shouldRevert) {
            revert("receiver revert");
        }

        tokenCaller = msg.sender;
        originalSender = _sender;
        amount = _value;
        data = _data;
    }
}

contract LinkTokenTest is Test {
    LinkToken private linkToken;
    LinkTokenReceiver private receiver;

    address private user = makeAddr("user");
    address private recipient = makeAddr("recipient");
    address private spender = makeAddr("spender");

    uint256 private constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 private constant MINT_AMOUNT = 25 ether;
    uint256 private constant TRANSFER_AMOUNT = 10 ether;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    function setUp() external {
        linkToken = new LinkToken();
        receiver = new LinkTokenReceiver();
    }

    function testMetadataIsCorrect() public view {
        assertEq(linkToken.name(), "LinkToken");
        assertEq(linkToken.symbol(), "LINK");
        assertEq(linkToken.decimals(), 18);
    }

    function testConstructorMintsInitialSupplyToDeployer() public view {
        assertEq(linkToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(linkToken.balanceOf(address(this)), INITIAL_SUPPLY);
    }

    function testMintIncreasesBalanceAndTotalSupply() public {
        linkToken.mint(user, MINT_AMOUNT);

        assertEq(linkToken.balanceOf(user), MINT_AMOUNT);
        assertEq(linkToken.totalSupply(), INITIAL_SUPPLY + MINT_AMOUNT);
    }

    function testTransferMovesTokensBetweenAccounts() public {
        linkToken.transfer(user, TRANSFER_AMOUNT);

        assertEq(linkToken.balanceOf(user), TRANSFER_AMOUNT);
        assertEq(
            linkToken.balanceOf(address(this)),
            INITIAL_SUPPLY - TRANSFER_AMOUNT
        );
    }

    function testTransferRevertsWhenBalanceIsTooLow() public {
        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        linkToken.transfer(recipient, TRANSFER_AMOUNT);
    }

    function testApproveSetsAllowanceAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(linkToken));
        emit Approval(address(this), spender, TRANSFER_AMOUNT);

        bool success = linkToken.approve(spender, TRANSFER_AMOUNT);

        assertTrue(success);
        assertEq(
            linkToken.allowance(address(this), spender),
            TRANSFER_AMOUNT
        );
    }

    function testTransferFromMovesApprovedTokensAndReducesAllowance() public {
        linkToken.approve(spender, TRANSFER_AMOUNT);

        vm.prank(spender);
        bool success = linkToken.transferFrom(
            address(this),
            recipient,
            TRANSFER_AMOUNT
        );

        assertTrue(success);
        assertEq(linkToken.balanceOf(recipient), TRANSFER_AMOUNT);
        assertEq(
            linkToken.balanceOf(address(this)),
            INITIAL_SUPPLY - TRANSFER_AMOUNT
        );
        assertEq(linkToken.allowance(address(this), spender), 0);
    }

    function testTransferFromDoesNotReduceMaxAllowance() public {
        linkToken.approve(spender, type(uint256).max);

        vm.prank(spender);
        linkToken.transferFrom(address(this), recipient, TRANSFER_AMOUNT);

        assertEq(linkToken.balanceOf(recipient), TRANSFER_AMOUNT);
        assertEq(
            linkToken.allowance(address(this), spender),
            type(uint256).max
        );
    }

    function testTransferFromRevertsWhenAllowanceIsTooLow() public {
        vm.prank(spender);
        vm.expectRevert(stdError.arithmeticError);
        linkToken.transferFrom(address(this), recipient, TRANSFER_AMOUNT);
    }

    function testTransferAndCallToEoaTransfersTokensAndEmitsEvent() public {
        bytes memory callData = abi.encode("fund-subscription");

        vm.expectEmit(true, true, false, true, address(linkToken));
        emit Transfer(address(this), recipient, TRANSFER_AMOUNT, callData);

        bool success = linkToken.transferAndCall(
            recipient,
            TRANSFER_AMOUNT,
            callData
        );

        assertTrue(success);
        assertEq(linkToken.balanceOf(recipient), TRANSFER_AMOUNT);
    }

    function testTransferAndCallInvokesReceiverContract() public {
        bytes memory callData = abi.encode(uint256(123));

        bool success = linkToken.transferAndCall(
            address(receiver),
            TRANSFER_AMOUNT,
            callData
        );

        assertTrue(success);
        assertEq(linkToken.balanceOf(address(receiver)), TRANSFER_AMOUNT);
        assertEq(receiver.tokenCaller(), address(linkToken));
        assertEq(receiver.originalSender(), address(this));
        assertEq(receiver.amount(), TRANSFER_AMOUNT);
        assertEq(keccak256(receiver.data()), keccak256(callData));
    }

    function testTransferAndCallRevertsIfReceiverReverts() public {
        receiver.setShouldRevert(true);

        vm.expectRevert(bytes("receiver revert"));
        linkToken.transferAndCall(address(receiver), TRANSFER_AMOUNT, "");

        assertEq(linkToken.balanceOf(address(receiver)), 0);
        assertEq(linkToken.balanceOf(address(this)), INITIAL_SUPPLY);
    }
}
