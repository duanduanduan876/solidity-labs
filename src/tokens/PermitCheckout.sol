// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract PermitCheckout {
    struct Order {
        address token;
        address merchant;
        uint256 amount;
        uint256 expiresAt;
        bool paid;
    }

    uint256 public nextOrderId = 1;
    mapping(uint256 => Order) public orders;

    error OrderNotFound();
    error OrderExpired();
    error OrderAlreadyPaid();
    error BadOrder();
    error PermitFailed();
    error TransferFromFailed();
    error DeadlineTooLarge();

    event OrderCreated(uint256 indexed orderId, address indexed token, address indexed merchant, uint256 amount, uint256 expiresAt);
    event Paid(uint256 indexed orderId, address indexed token, address indexed payer, address merchant, uint256 amount);

    function createOrder(address token, uint256 amount, uint256 expiresAt) external returns (uint256 orderId) {
        if (token == address(0) || amount == 0 || expiresAt <= block.timestamp) revert BadOrder();

        orderId = nextOrderId++;
        orders[orderId] = Order({
            token: token,
            merchant: msg.sender,
            amount: amount,
            expiresAt: expiresAt,
            paid: false
        });

        emit OrderCreated(orderId, token, msg.sender, amount, expiresAt);
    }

    function pay(
        uint256 orderId,
        address owner,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        Order storage o = orders[orderId];
        if (o.merchant == address(0)) revert OrderNotFound();
        if (o.paid) revert OrderAlreadyPaid();
        if (block.timestamp > o.expiresAt) revert OrderExpired();

        // 关键：permitDeadline 不允许超过订单过期时间（避免签永久授权）
        if (permitDeadline > o.expiresAt) revert DeadlineTooLarge();

        IERC20 token = IERC20(o.token);

        uint256 allowance = token.allowance(owner, address(this));
        if (allowance < o.amount) {
            // 抗 DoS：permit 可能被抢跑导致 nonce 变化 -> 本次 permit 失败
            // 但如果抢跑已把 allowance 提上来，再读一次即可通过
            try IERC20Permit(o.token).permit(owner, address(this), o.amount, permitDeadline, v, r, s) {
            } catch {
                uint256 allowance2 = token.allowance(owner, address(this));
                if (allowance2 < o.amount) revert PermitFailed();
            }
        }

        bool ok = token.transferFrom(owner, o.merchant, o.amount);
        if (!ok) revert TransferFromFailed();

        o.paid = true;
        emit Paid(orderId, o.token, owner, o.merchant, o.amount);
    }
}
