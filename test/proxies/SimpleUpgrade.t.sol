// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {SimpleUpgrade, Logic1, Logic2} from "../../src/proxies/SimpleUpgrade.sol";

contract SimpleUpgradeTest is Test {
    SimpleUpgrade internal proxy;
    Logic1 internal l1;
    Logic2 internal l2;

    address internal attacker = address(0xB0B);

    function setUp() public {
        l1 = new Logic1();
        l2 = new Logic2();

        // 测试合约自己部署 proxy，因此 admin = address(this)
        proxy = new SimpleUpgrade(address(l1));
    }

    function test_v1_callFoo_setsOld() public {
        // 通过“把 proxy 地址当成 Logic1”来调用 foo()，会触发 fallback -> delegatecall
        Logic1(address(proxy)).foo();

        assertEq(proxy.words(), "old");
        assertEq(proxy.implementation(), address(l1));
        assertEq(proxy.admin(), address(this));
    }

    function test_upgrade_preserves_state_then_changes_behavior() public {
        // 先跑 v1：写入 old
        Logic1(address(proxy)).foo();
        assertEq(proxy.words(), "old");

        // 升级到 v2（注意：升级本身不应改变 words）
        proxy.upgrade(address(l2));
        assertEq(proxy.implementation(), address(l2));
        assertEq(proxy.words(), "old"); // 状态保留（关键加分点）

        // 再跑 foo：行为变成 new
        Logic2(address(proxy)).foo();
        assertEq(proxy.words(), "new");
    }

    function test_onlyAdmin_can_upgrade() public {
        vm.prank(attacker);
        vm.expectRevert("not admin");
        proxy.upgrade(address(l2));

        // 确保没被改
        assertEq(proxy.implementation(), address(l1));
    }
}
