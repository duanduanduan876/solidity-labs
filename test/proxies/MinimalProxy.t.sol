// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Proxy, Logic, Caller} from "../../src/proxies/MinimalProxy.sol";

contract MinimalProxyTest is Test {
    Logic internal logic;
    Proxy internal proxy;
    Caller internal caller;

    function setUp() public {
        logic = new Logic();
        proxy = new Proxy(address(logic));
        caller = new Caller(address(proxy));
    }

    function test_directCall_logicHasX99() public {
        // 直调 Logic：x = 99 -> increment() 返回 100
        uint256 r = logic.increment();
        assertEq(r, 100);

        // 直调 readX() 看到 99
        assertEq(logic.readX(), 99);
    }

    function test_proxyCall_readsProxyStorage_xIsZero() public {
        // 通过 Proxy 调：Logic 代码执行，但读的是 Proxy 的 slot1（默认 0）
        // 所以 increment() 返回 1
        uint256 r = caller.increment();
        assertEq(r, 1);

        // 通过代理 readX() 读到的也是 Proxy.slot1 = 0
        assertEq(caller.readX(), 0);

        // Proxy.slot0 implementation 应该等于 logic 地址
        assertEq(proxy.implementation(), address(logic));
    }

    function test_proxyDoesNotChangeProxyStorageX() public {
        // 你这个 Logic.increment() 只读不写
        // 所以无论调用多少次，代理下永远是 1
        assertEq(caller.increment(), 1);
        assertEq(caller.increment(), 1);
        assertEq(caller.readX(), 0);
    }
}
