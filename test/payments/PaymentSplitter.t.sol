// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { PaymentSplitter } from "src/payments/PaymentSplitter.sol";

contract GasHog {
    uint256 public sink;
    receive() external payable {
        for (uint256 i = 0; i < 10_000; i++) {
            sink += i;
        }
    }
}

contract PaymentSplitterTest is Test {
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    address carol = makeAddr("carol");

    PaymentSplitter ps;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);

        payees[0] = alice; shares[0] = 1;
        payees[1] = bob;   shares[1] = 3;

        ps = new PaymentSplitter(payees, shares);
    }

    function test_Constructor_Revert_LengthMismatch() public {
        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](1);
        payees[0] = alice; payees[1] = bob;
        shares[0] = 1;

        vm.expectRevert(bytes("PaymentSplitter: payees and shares length mismatch"));
        new PaymentSplitter(payees, shares);
    }

    function test_Constructor_Revert_NoPayees() public {
        address[] memory payees = new address[](0);
        uint256[] memory shares = new uint256[](0);

        vm.expectRevert(bytes("PaymentSplitter: no payees"));
        new PaymentSplitter(payees, shares);
    }

    function test_Constructor_Revert_ZeroAddress() public {
        address[] memory payees = new address[](1);
        uint256[] memory shares = new uint256[](1);
        payees[0] = address(0);
        shares[0] = 1;

        vm.expectRevert(bytes("PaymentSplitter: account is the zero address"));
        new PaymentSplitter(payees, shares);
    }

    function test_Constructor_Revert_ZeroShares() public {
        address[] memory payees = new address[](1);
        uint256[] memory shares = new uint256[](1);
        payees[0] = alice;
        shares[0] = 0;

        vm.expectRevert(bytes("PaymentSplitter: shares are 0"));
        new PaymentSplitter(payees, shares);
    }

    function test_Constructor_Revert_DuplicatePayee() public {
        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);
        payees[0] = alice; shares[0] = 1;
        payees[1] = alice; shares[1] = 1;

        vm.expectRevert(bytes("PaymentSplitter: account already has shares"));
        new PaymentSplitter(payees, shares);
    }

    function test_Deposit_IncreasesTotalReceived() public {
        assertEq(ps.totalReceived(), 0);
        ps.deposit{value: 10 ether}();
        assertEq(ps.totalReceived(), 10 ether);

        (bool ok,) = address(ps).call{value: 2 ether}("");
        require(ok, "send failed");
        assertEq(ps.totalReceived(), 12 ether);
    }

    function test_Releasable_CorrectByShares() public {
        ps.deposit{value: 40 ether}();
        assertEq(ps.releasable(alice), 10 ether);
        assertEq(ps.releasable(bob), 30 ether);
    }

    function test_Release_Success_PaysAndUpdatesState() public {
        ps.deposit{value: 40 ether}();

        uint256 aliceBefore = alice.balance;
        ps.release(payable(alice));
        assertEq(alice.balance, aliceBefore + 10 ether);
        assertEq(ps.released(alice), 10 ether);
        assertEq(ps.releasable(alice), 0);
    }

    function test_Release_Revert_NoShares() public {
        ps.deposit{value: 1 ether}();
        vm.expectRevert(bytes("PaymentSplitter: account has no shares"));
        ps.release(payable(carol));
    }

    function test_Release_Revert_NotDue() public {
        vm.expectRevert(bytes("PaymentSplitter: account is not due payment"));
        ps.release(payable(alice));
    }

    function test_Release_ToGasHog_SucceedsBecauseCall() public {
        GasHog hog = new GasHog();
        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);
        payees[0] = address(hog); shares[0] = 1;
        payees[1] = bob;          shares[1] = 1;

        PaymentSplitter ps2 = new PaymentSplitter(payees, shares);
        ps2.deposit{value: 2 ether}();

        uint256 hogBefore = address(hog).balance;
        ps2.release(payable(address(hog)));
        assertEq(address(hog).balance, hogBefore + 1 ether);
    }
}

