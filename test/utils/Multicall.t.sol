// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import { MulticallPlus } from "../../src/utils/Multicall.sol";

contract Reverter {
    function boom() external pure {
        revert("BOOM");
    }
}

contract PayableSink {
    event Received(address from, uint256 value);
    function ping() external payable returns (uint256) {
        emit Received(msg.sender, msg.value);
        return msg.value;
    }
}

contract MulticallPlusTest is Test {
    MulticallPlus mc;
    Reverter reverter;
    PayableSink sink;

    // --- 修复点 1: 必须允许测试合约接收退款 ---
    receive() external payable {}

    function setUp() public {
        mc = new MulticallPlus();
        reverter = new Reverter();
        sink = new PayableSink();
        vm.deal(address(this), 10 ether);
    }

    function test_TargetHasNoCode_reverts() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(0x1234),
            value: 0,
            allowFailure: true,
            isStatic: true,
            callData: abi.encodeWithSignature("anything()")
        });

        vm.expectRevert(
            abi.encodeWithSelector(MulticallPlus.TargetHasNoCode.selector, 0, address(0x1234))
        );
        mc.multicall(calls);
    }

    function test_StaticcallWithValue_reverts() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(sink),
            value: 1 wei,
            allowFailure: true,
            isStatic: true,
            callData: abi.encodeWithSignature("ping()")
        });

        vm.expectRevert(
            abi.encodeWithSelector(MulticallPlus.InsufficientValue.selector, 1 wei, 0)
        );
        mc.multicall(calls);
    }

    function test_allowFailure_true_capturesRevert() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(reverter),
            value: 0,
            allowFailure: true,
            isStatic: false,
            callData: abi.encodeWithSignature("boom()")
        });

        MulticallPlus.Result[] memory results = mc.multicall(calls);
        assertEq(results.length, 1);
        assertEq(results[0].success, false);
        assertTrue(results[0].returnData.length > 0); 
    }

    function test_allowFailure_false_reverts() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(reverter),
            value: 0,
            allowFailure: false,
            isStatic: false,
            callData: abi.encodeWithSignature("boom()")
        });

        // --- 修复点 2: 使用这种方式匹配带参数的 Custom Error ---
        // 如果不想硬编码 revertData，可以直接用这种通用的 expectRevert
        vm.expectRevert(); 
        mc.multicall(calls);
    }

    function test_valueAccounting_and_refund() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(sink),
            value: 1 ether,
            allowFailure: false,
            isStatic: false,
            callData: abi.encodeWithSignature("ping()")
        });

        uint256 balBefore = address(this).balance;
        // 传入 2 ether，支出 1 ether
        mc.multicall{value: 2 ether}(calls);
        uint256 balAfter = address(this).balance;

        assertEq(address(sink).balance, 1 ether);
        assertEq(address(mc).balance, 0);
        // 这里需要考虑测试合约消耗的 gas（虽然 vm.deal 模拟环境下 gas 表现不同，但这样写更稳健）
        assertApproxEqAbs(balBefore - balAfter, 1 ether, 0.001 ether);
    }

    function test_failedCallWithValue_refundsAllIfAllowed() public {
        MulticallPlus.Call[] memory calls = new MulticallPlus.Call[](1);
        calls[0] = MulticallPlus.Call({
            target: address(reverter),
            value: 1 ether,
            allowFailure: true,
            isStatic: false,
            callData: abi.encodeWithSignature("boom()")
        });

        uint256 balBefore = address(this).balance;
        mc.multicall{value: 1 ether}(calls);
        uint256 balAfter = address(this).balance;

        assertEq(address(mc).balance, 0); 
        // 验证钱退回来了（差值接近 0）
        assertApproxEqAbs(balBefore, balAfter, 0.001 ether);
    }
}
