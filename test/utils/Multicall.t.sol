// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { Multicall } from "src/utils/Multicall.sol";

contract MockTarget {
    uint256 public value;

    event ValueSet(uint256 v);

    // ✅ 修复警告：增加 receive 函数
    receive() external payable {}

    function setValue(uint256 v) external {
        value = v;
        emit ValueSet(v);
    }

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    function whoCalled() external view returns (address) {
        return msg.sender;
    }

    function revertAlways() external pure {
        revert("MockTarget: revertAlways");
    }

    fallback() external payable {
        revert("MockTarget: fallback revert");
    }
}

contract MulticallTest is Test {
    Multicall mc;
    MockTarget target;

    function setUp() public {
        mc = new Multicall();
        target = new MockTarget();
    }

    function _call(
        address t,
        bool allowFailure,
        bytes memory data
    ) internal pure returns (Multicall.Call memory) {
        return Multicall.Call({target: t, allowFailure: allowFailure, callData: data});
    }

    function test_Multicall_EmptyCalls_ReturnsEmpty() public {
        // ✅ 修复：声明并初始化长度为 0 的数组
        Multicall.Call[] memory calls = new Multicall.Call[](0);
        Multicall.Result[] memory results = mc.multicall(calls);
        assertEq(results.length, 0);
    }

    function test_Multicall_AllSuccess_StateChangeAndReturnData() public {
        // ✅ 修复：初始化长度为 2 的数组
        Multicall.Call[] memory calls = new Multicall.Call[](2);

        calls[0] = _call(address(target), false, abi.encodeWithSelector(target.setValue.selector, 123));
        calls[1] = _call(address(target), false, abi.encodeWithSelector(target.add.selector, 3, 4));

        Multicall.Result[] memory results = mc.multicall(calls);

        assertEq(results.length, 2);

        // call[0]
        assertTrue(results[0].success);
        assertEq(target.value(), 123);
        assertEq(results[0].returnData.length, 0);

        // call[1]
        assertTrue(results[1].success);
        uint256 sum = abi.decode(results[1].returnData, (uint256));
        assertEq(sum, 7);
    }

    function test_Multicall_AllowFailureTrue_CapturesRevertData_DoesNotRevert() public {
        Multicall.Call[] memory calls = new Multicall.Call[](2);

        calls[0] = _call(address(target), false, abi.encodeWithSelector(target.setValue.selector, 999));
        calls[1] = _call(address(target), true, abi.encodeWithSelector(target.revertAlways.selector));

        Multicall.Result[] memory results = mc.multicall(calls);

        assertEq(results.length, 2);
        assertTrue(results[0].success);
        assertEq(target.value(), 999);

        assertFalse(results[1].success);
        bytes memory rd = results[1].returnData;
        bytes4 sel;
        if (rd.length >= 4) {
            assembly {
                sel := mload(add(rd, 0x20))
            }
        }
        // ✅ 修复报错：将 bytes4 显式转换为 uint32 进行比较
        assertEq(uint32(sel), uint32(0x08c379a0)); 
    }

    function test_Multicall_AllowFailureFalse_FailsWholeBatch_AndRollsBackPriorEffects() public {
        // ✅ 修复：初始化数组
        Multicall.Call[] memory calls = new Multicall.Call[](2);

        calls[0] = _call(address(target), false, abi.encodeWithSelector(target.setValue.selector, 555));
        calls[1] = _call(address(target), false, abi.encodeWithSelector(target.revertAlways.selector));

        vm.expectRevert(bytes("Multicall: call failed"));
        mc.multicall(calls);

        assertEq(target.value(), 0);
    }

    function test_Multicall_MsgSenderInsideTarget_IsMulticall() public {
        // ✅ 修复：初始化数组
        Multicall.Call[] memory calls = new Multicall.Call[](1);
        calls[0] = _call(address(target), false, abi.encodeWithSelector(target.whoCalled.selector));

        Multicall.Result[] memory results = mc.multicall(calls);
        assertTrue(results[0].success);

        address caller = abi.decode(results[0].returnData, (address));
        assertEq(caller, address(mc));
    }

    function test_Multicall_CallToEOA_SucceedsWithEmptyReturnData() public {
        address eoa = makeAddr("eoa");

        // ✅ 修复：初始化数组
        Multicall.Call[] memory calls = new Multicall.Call[](1);
        calls[0] = _call(eoa, true, hex"12345678");

        Multicall.Result[] memory results = mc.multicall(calls);
        assertEq(results.length, 1);
        assertTrue(results[0].success);
        assertEq(results[0].returnData.length, 0);
    }

    function test_Multicall_EmptyCalldata_HitsFallback_CanBeAllowedOrNot() public {
        // ✅ 修复：初始化 calls1 和 calls2
        Multicall.Call[] memory calls1 = new Multicall.Call[](1);
        calls1[0] = _call(address(target), true, bytes(""));
        Multicall.Result[] memory r1 = mc.multicall(calls1);
        assertFalse(r1[0].success);

        Multicall.Call[] memory calls2 = new Multicall.Call[](1);
        calls2[0] = _call(address(target), false, bytes(""));
        vm.expectRevert(bytes("Multicall: call failed"));
        mc.multicall(calls2);
    }
}
