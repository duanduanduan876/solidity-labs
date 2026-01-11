// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DemoUUPSProxy, DemoUUPS1, DemoUUPS2} from "../../src/proxies/DemoUUPS.sol";

interface IDemoUUPS {
    function foo() external;
    function upgrade(address newImplementation) external;
    function version() external pure returns (string memory);
}

contract DemoUUPSTest is Test {
    DemoUUPS1 internal u1;
    DemoUUPS2 internal u2;
    DemoUUPSProxy internal proxy;

    address internal user = address(0xA11CE);

    function setUp() public {
        u1 = new DemoUUPS1();
        u2 = new DemoUUPS2();

        // admin = address(this)
        proxy = new DemoUUPSProxy(address(u1));
    }

    function test_uups_flow_upgrade_preserves_state() public {
        // 通过代理读版本（return data 冒泡）
        assertEq(IDemoUUPS(address(proxy)).version(), "DemoUUPS1");

        // 非 admin 调业务函数 OK
        vm.prank(user);
        IDemoUUPS(address(proxy)).foo();
        assertEq(proxy.words(), "old");

        // admin 通过代理调用 upgrade（注意：upgrade 在 logic 内）
        IDemoUUPS(address(proxy)).upgrade(address(u2));
        assertEq(proxy.implementation(), address(u2));

        // 升级后状态不丢（words 还在）
        assertEq(proxy.words(), "old");

        // 业务行为切换
        vm.prank(user);
        IDemoUUPS(address(proxy)).foo();
        assertEq(proxy.words(), "new");
        assertEq(IDemoUUPS(address(proxy)).version(), "DemoUUPS2");
    }

    function test_only_admin_can_upgrade() public {
        vm.prank(user);
        vm.expectRevert("only admin");
        IDemoUUPS(address(proxy)).upgrade(address(u2));

        // 没升级成功
        assertEq(proxy.implementation(), address(u1));
    }

    function test_changeAdmin_then_new_admin_can_upgrade() public {
        // admin 把代理的 admin 改成 user
        proxy.changeAdmin(user);
        assertEq(proxy.admin(), user);

        // 旧 admin（address(this)）再升级会失败
        vm.expectRevert("only admin");
        IDemoUUPS(address(proxy)).upgrade(address(u2));

        // 新 admin 升级成功
        vm.prank(user);
        IDemoUUPS(address(proxy)).upgrade(address(u2));
        assertEq(proxy.implementation(), address(u2));

        // 从 DemoUUPS2 再升级回 DemoUUPS1（证明升级通道没堵死）
        vm.prank(user);
        IDemoUUPS(address(proxy)).upgrade(address(u1));
        assertEq(proxy.implementation(), address(u1));
        assertEq(IDemoUUPS(address(proxy)).version(), "DemoUUPS1");
    }
}
