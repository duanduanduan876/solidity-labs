// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TransparentProxy, TPLogic1, TPLogic2} from "../../src/proxies/TransparentProxy.sol";

interface ITPLogic {
    function foo() external;
    function version() external pure returns (string memory);
}

contract TransparentProxyTest is Test {
    TransparentProxy internal proxy;
    TPLogic1 internal l1;
    TPLogic2 internal l2;

    address internal user = address(0xA11CE); // 非管理员

    function setUp() public {
        l1 = new TPLogic1();
        l2 = new TPLogic2();

        // admin = address(this)
        proxy = new TransparentProxy(address(l1));
    }

    function test_nonAdmin_can_call_logic_and_get_return() public {
        // non-admin 可以走 fallback -> delegatecall
        vm.prank(user);
        assertEq(ITPLogic(address(proxy)).version(), "Logic1"); // 如果你改成 TPLogic1，这里也改

        vm.prank(user);
        ITPLogic(address(proxy)).foo();
        assertEq(proxy.words(), "old");
    }

    function test_admin_cannot_call_logic() public {
        // admin 走 fallback 会被禁止（透明代理核心规则）
        vm.expectRevert(bytes("TransparentProxy: admin cannot call logic"));
        ITPLogic(address(proxy)).version();

        vm.expectRevert(bytes("TransparentProxy: admin cannot call logic"));
        ITPLogic(address(proxy)).foo();
    }

    function test_onlyAdmin_can_upgrade() public {
        // 非 admin 升级应失败
        vm.prank(user);
        vm.expectRevert(bytes("TransparentProxy: bushi admin"));
        proxy.upgrade(address(l2));

        assertEq(proxy.implementation(), address(l1));
    }

    function test_upgrade_switches_behavior_and_preserves_state() public {
        // 先在 v1 写入 old
        vm.prank(user);
        ITPLogic(address(proxy)).foo();
        assertEq(proxy.words(), "old");

        // admin 升级到 v2，状态应保留
        proxy.upgrade(address(l2));
        assertEq(proxy.implementation(), address(l2));
        assertEq(proxy.words(), "old");

        // v2 行为生效：foo -> new
        vm.prank(user);
        ITPLogic(address(proxy)).foo();
        assertEq(proxy.words(), "new");

        // 返回值也应该变成 v2
        vm.prank(user);
        assertEq(ITPLogic(address(proxy)).version(), "Logic2"); // 如果你改成 TPLogic2，这里也改
    }
}
