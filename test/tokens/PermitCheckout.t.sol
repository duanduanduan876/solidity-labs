// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {InterviewPermitToken} from "../../src/tokens/InterviewPermitToken.sol";
import {PermitCheckout} from "../../src/tokens/PermitCheckout.sol";

contract PermitCheckoutTest is Test {
    InterviewPermitToken token;
    PermitCheckout checkout;

    uint256 buyerPk;
    address buyer;
    address merchant;
    address relayer;
    address attacker;

    bytes32 constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function setUp() public {
        token = new InterviewPermitToken("InterviewPermitToken", "IPT", 0);
        checkout = new PermitCheckout();

        buyerPk = 0xA11CE;
        buyer = vm.addr(buyerPk);

        merchant = address(0x1111);
        relayer  = address(0x2222);
        attacker = address(0x3333);

        token.mint(buyer, 1_000e18);
    }

    function _signPermit(
        uint256 pk,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        (v, r, s) = vm.sign(pk, digest);
    }

    function testPayWithPermitHappyPath() public {
        uint256 amount = 100e18;
        uint256 expiresAt = block.timestamp + 1 days;

        vm.prank(merchant);
        uint256 orderId = checkout.createOrder(address(token), amount, expiresAt);

        uint256 nonce = token.nonces(buyer);
        uint256 permitDeadline = expiresAt; // 必须 <= expiresAt

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(buyerPk, buyer, address(checkout), amount, nonce, permitDeadline);

        uint256 buyerBefore = token.balanceOf(buyer);
        uint256 merchantBefore = token.balanceOf(merchant);

        vm.prank(relayer);
        checkout.pay(orderId, buyer, permitDeadline, v, r, s);

        (, , , , bool paid) = checkout.orders(orderId);
        assertTrue(paid);

        assertEq(token.balanceOf(merchant), merchantBefore + amount);
        assertEq(token.balanceOf(buyer), buyerBefore - amount);
        assertEq(token.allowance(buyer, address(checkout)), 0);
    }

    function testPaySurvivesPermitFrontRunDoS() public {
        uint256 amount = 100e18;
        uint256 expiresAt = block.timestamp + 1 days;

        vm.prank(merchant);
        uint256 orderId = checkout.createOrder(address(token), amount, expiresAt);

        uint256 nonce = token.nonces(buyer);
        uint256 permitDeadline = expiresAt;

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermit(buyerPk, buyer, address(checkout), amount, nonce, permitDeadline);

        // attacker 抢跑先执行 permit（nonce 被用掉）
        vm.prank(attacker);
        token.permit(buyer, address(checkout), amount, permitDeadline, v, r, s);

        // 订单支付应成功：因为 allowance 已经足够，pay 不再依赖 permit 成功
        vm.prank(relayer);
        checkout.pay(orderId, buyer, permitDeadline, v, r, s);

        (, , , , bool paid) = checkout.orders(orderId);
        assertTrue(paid);
    }

    function testRevertWhenPermitDeadlineTooLarge() public {
        uint256 amount = 100e18;
        uint256 expiresAt = block.timestamp + 1 days;

        vm.prank(merchant);
        uint256 orderId = checkout.createOrder(address(token), amount, expiresAt);

        vm.expectRevert(PermitCheckout.DeadlineTooLarge.selector);
        vm.prank(relayer);
        checkout.pay(orderId, buyer, expiresAt + 1, 0, bytes32(0), bytes32(0));
    }
}
