// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Mock imports
import { OFTMock } from "../mocks/OFTMock.sol";
import { OFTComposerMock } from "../mocks/OFTComposerMock.sol";

// OApp imports
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// OFT imports
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

// Contract imports
import { KWRC } from "../../contracts/krwc-test1/KWRC.sol";
import { TransferLimit } from "../../contracts/krwc-test1/types/TransferLimitTypes.sol";
import { IFeeManager } from "../../contracts/krwc-test1/interfaces/IFeeManager.sol";

// Mock FeeManager for testing
contract MockFeeManager is IFeeManager {
    function handleFee(address from, uint256 amount) external pure returns (uint256) {
        return amount; // Return the same amount for testing
    }
}

contract KWRCTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    KWRC private aKWRC;
    KWRC private bKWRC;
    MockFeeManager private feeManager;

    address private admin = makeAddr("admin");
    address private owner = makeAddr("owner");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    address private delegate = makeAddr("delegate");

    uint256 private initialBalance = 1000 ether;
    uint256 private feeRate = 100; // 1%

    TransferLimit[] private transferLimits;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(admin, 1000 ether);
        vm.deal(owner, 1000 ether);
        vm.deal(delegate, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy fee manager
        feeManager = new MockFeeManager();

        // Setup transfer limits
        transferLimits.push(
            TransferLimit({
                dstEid: bEid,
                maxDailyTransferAmount: 10000 ether,
                singleTransferUpperLimit: 1000 ether,
                singleTransferLowerLimit: 0.1 ether,
                dailyTransferAmountPerAddress: 500 ether,
                dailyTransferAttemptPerAddress: 10
            })
        );

        // Deploy KWRC contracts
        aKWRC = KWRC(
            _deployOApp(
                type(KWRC).creationCode,
                abi.encode(
                    "KRW Coin A",
                    "KWRC-A",
                    address(endpoints[aEid]),
                    delegate,
                    address(feeManager),
                    feeRate,
                    transferLimits,
                    admin,
                    owner
                )
            )
        );

        bKWRC = KWRC(
            _deployOApp(
                type(KWRC).creationCode,
                abi.encode(
                    "KRW Coin B",
                    "KWRC-B",
                    address(endpoints[bEid]),
                    delegate,
                    address(feeManager),
                    feeRate,
                    transferLimits,
                    admin,
                    owner
                )
            )
        );

        // Config and wire the KWRC contracts
        address[] memory kwrcs = new address[](2);
        kwrcs[0] = address(aKWRC);
        kwrcs[1] = address(bKWRC);
        this.wireOApps(kwrcs);

        // Mint initial tokens to users
        vm.prank(admin);
        aKWRC.mint(userA, initialBalance);
        vm.prank(admin);
        bKWRC.mint(userB, initialBalance);
    }

    function test_constructor() public {
        assertEq(aKWRC.owner(), owner);
        assertEq(bKWRC.owner(), owner);

        assertTrue(aKWRC.hasRole(aKWRC.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(aKWRC.hasRole(aKWRC.ADMIN_ROLE(), admin));
        assertTrue(aKWRC.hasRole(aKWRC.MINTER_ROLE(), admin));

        assertEq(aKWRC.feeRate(), feeRate);
        assertEq(aKWRC.feeManager(), address(feeManager));

        assertEq(aKWRC.balanceOf(userA), initialBalance);
        assertEq(bKWRC.balanceOf(userB), initialBalance);
    }

    function test_transfer_with_fee() public {
        uint256 transferAmount = 100 ether;
        uint256 expectedFee = (transferAmount * feeRate) / 10_000; // 1 ether
        uint256 expectedNetAmount = transferAmount - expectedFee;

        uint256 balanceBefore = aKWRC.balanceOf(userA);

        vm.prank(userA);
        aKWRC.transfer(userB, transferAmount);

        assertEq(aKWRC.balanceOf(userA), balanceBefore - transferAmount);
        assertEq(aKWRC.balanceOf(userB), initialBalance + expectedNetAmount);
    }

    function test_transfer_without_fee_manager() public {
        // Deploy KWRC without fee manager
        TransferLimit[] memory emptyLimits;
        KWRC noFeeKWRC = KWRC(
            _deployOApp(
                type(KWRC).creationCode,
                abi.encode(
                    "No Fee KWRC",
                    "NFKWRC",
                    address(endpoints[aEid]),
                    delegate,
                    address(0), // No fee manager
                    0, // No fee rate
                    emptyLimits,
                    admin,
                    owner
                )
            )
        );

        vm.prank(admin);
        noFeeKWRC.mint(userA, 100 ether);

        uint256 transferAmount = 50 ether;
        vm.prank(userA);
        noFeeKWRC.transfer(userB, transferAmount);

        assertEq(noFeeKWRC.balanceOf(userB), transferAmount);
    }

    function test_transfer_limit_single_transfer() public {
        uint256 transferAmount = 1000 ether; // At the upper limit

        vm.prank(userA);
        aKWRC.transfer(userB, transferAmount);

        // Try to transfer more than the limit
        vm.prank(userA);
        vm.expectRevert(); // Should revert due to transfer limit
        aKWRC.transfer(userB, 1001 ether);
    }

    function test_transfer_limit_daily_amount() public {
        uint256 dailyLimit = 500 ether;
        uint256 transferAmount = 300 ether;

        // First transfer should succeed
        vm.prank(userA);
        aKWRC.transfer(userB, transferAmount);

        // Second transfer that exceeds daily limit should fail
        vm.prank(userA);
        vm.expectRevert(); // Should revert due to daily transfer limit
        aKWRC.transfer(userB, 250 ether);
    }

    function test_transfer_limit_daily_attempts() public {
        uint256 transferAmount = 10 ether;

        // Make 10 transfers (at the limit)
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(userA);
            aKWRC.transfer(userB, transferAmount);
        }

        // 11th transfer should fail
        vm.prank(userA);
        vm.expectRevert(); // Should revert due to daily attempt limit
        aKWRC.transfer(userB, transferAmount);
    }

    function test_send_oft() public {
        uint256 tokensToSend = 100 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aKWRC.quoteSend(sendParam, false);

        uint256 balanceBefore = aKWRC.balanceOf(userA);
        uint256 balanceBeforeB = bKWRC.balanceOf(userB);

        vm.prank(userA);
        aKWRC.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bKWRC)));

        // Check that tokens were deducted from sender (with fee)
        uint256 expectedFee = (tokensToSend * feeRate) / 10_000;
        uint256 expectedNetAmount = tokensToSend - expectedFee;
        assertEq(aKWRC.balanceOf(userA), balanceBefore - tokensToSend);

        // Check that tokens were received by recipient (without fee on destination)
        assertEq(bKWRC.balanceOf(userB), balanceBeforeB + tokensToSend);
    }

    function test_send_oft_with_compose_msg() public {
        uint256 tokensToSend = 50 ether;
        OFTComposerMock composer = new OFTComposerMock();

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(200000, 0)
            .addExecutorLzComposeOption(0, 500000, 0);
        bytes memory composeMsg = hex"1234";
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(address(composer)),
            tokensToSend,
            tokensToSend,
            options,
            composeMsg,
            ""
        );
        MessagingFee memory fee = aKWRC.quoteSend(sendParam, false);

        vm.prank(userA);
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = aKWRC.send{ value: fee.nativeFee }(
            sendParam,
            fee,
            payable(address(this))
        );
        verifyPackets(bEid, addressToBytes32(address(bKWRC)));

        // lzCompose params
        uint32 dstEid_ = bEid;
        address from_ = address(bKWRC);
        bytes memory options_ = options;
        bytes32 guid_ = msgReceipt.guid;
        address to_ = address(composer);
        bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
            msgReceipt.nonce,
            aEid,
            oftReceipt.amountReceivedLD,
            abi.encodePacked(addressToBytes32(userA), composeMsg)
        );
        this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

        assertEq(bKWRC.balanceOf(address(composer)), tokensToSend);
        assertEq(composer.from(), from_);
        assertEq(composer.guid(), guid_);
        assertEq(composer.message(), composerMsg_);
    }

    function test_access_control_mint() public {
        uint256 mintAmount = 100 ether;

        // Admin can mint
        vm.prank(admin);
        aKWRC.mint(userA, mintAmount);
        assertEq(aKWRC.balanceOf(userA), initialBalance + mintAmount);

        // Non-admin cannot mint
        vm.prank(userA);
        vm.expectRevert();
        aKWRC.mint(userB, mintAmount);
    }

    function test_access_control_burn() public {
        uint256 burnAmount = 10 ether;

        // Admin can burn
        vm.prank(admin);
        aKWRC.burn(userA, burnAmount);
        assertEq(aKWRC.balanceOf(userA), initialBalance - burnAmount);

        // Non-admin cannot burn
        vm.prank(userA);
        vm.expectRevert();
        aKWRC.burn(userB, burnAmount);
    }

    function test_fee_rate_update() public {
        uint256 newFeeRate = 200; // 2%

        // Owner can update fee rate
        vm.prank(owner);
        aKWRC.setFeeRate(newFeeRate);
        assertEq(aKWRC.feeRate(), newFeeRate);

        // Non-owner cannot update fee rate
        vm.prank(userA);
        vm.expectRevert();
        aKWRC.setFeeRate(300);
    }

    function test_fee_manager_update() public {
        address newFeeManager = makeAddr("newFeeManager");

        // Owner can update fee manager
        vm.prank(owner);
        aKWRC.setFeeManager(newFeeManager);
        assertEq(aKWRC.feeManager(), newFeeManager);

        // Non-owner cannot update fee manager
        vm.prank(userA);
        vm.expectRevert();
        aKWRC.setFeeManager(makeAddr("anotherFeeManager"));
    }

    function test_transfer_to_zero_address() public {
        vm.prank(userA);
        vm.expectRevert("KWRC: transfer to the zero address");
        aKWRC.transfer(address(0), 10 ether);
    }

    function test_transfer_limit_reset_after_24_hours() public {
        uint256 transferAmount = 300 ether;

        // First transfer
        vm.prank(userA);
        aKWRC.transfer(userB, transferAmount);

        // Try to transfer more (should fail due to daily limit)
        vm.prank(userA);
        vm.expectRevert();
        aKWRC.transfer(userB, 250 ether);

        // Fast forward 24 hours
        vm.warp(block.timestamp + 1 days);

        // Now should be able to transfer again
        vm.prank(userA);
        aKWRC.transfer(userB, 200 ether);
    }

    function test_transfer_limit_lower_limit() public {
        uint256 smallAmount = 0.05 ether; // Below lower limit

        vm.prank(userA);
        vm.expectRevert(); // Should revert due to lower limit
        aKWRC.transfer(userB, smallAmount);
    }

    function test_oft_transfer_with_limits() public {
        uint256 tokensToSend = 1000 ether; // At the upper limit
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aKWRC.quoteSend(sendParam, false);

        vm.prank(userA);
        aKWRC.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bKWRC)));

        // Try to send more than the limit
        SendParam memory sendParam2 = SendParam(bEid, addressToBytes32(userB), 1001 ether, 1001 ether, options, "", "");
        MessagingFee memory fee2 = aKWRC.quoteSend(sendParam2, false);

        vm.prank(userA);
        vm.expectRevert(); // Should revert due to transfer limit
        aKWRC.send{ value: fee2.nativeFee }(sendParam2, fee2, payable(address(this)));
    }
}
