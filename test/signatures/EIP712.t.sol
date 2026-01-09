// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EIP712Storage} from "../../src/signatures/EIP712Auth.sol";

contract EIP712StorageTest is Test {
    EIP712Storage eip;

    // 伪造私钥（测试用，别用真实钱包私钥）
    uint256 internal ownerPk = 0xA11CE;
    uint256 internal spenderPk = 0xB0B;
    uint256 internal otherPk = 0xCA11;

    address internal owner;
    address internal spender;
    address internal other;

    // 在测试里重声明事件，便于 expectEmit
    event NumberChanged(uint256 indexed oldValue, uint256 indexed newValue, address indexed by);

    function setUp() public {
        owner = vm.addr(ownerPk);
        spender = vm.addr(spenderPk);
        other = vm.addr(otherPk);

        // 关键：用 prank 部署，让合约 owner = 我们控制的 owner 地址
        vm.prank(owner);
        eip = new EIP712Storage();
    }

    function _signFor(address _spender, uint256 number, uint256 pk) internal view returns (bytes memory) {
        bytes32 digest = eip.hashTypedData(_spender, number);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v); // ECDSA.recover(bytes) 需要 r||s||v
    }

    function test_permitStore_updates_number_and_emits() public {
        uint256 newNumber = 123;

        // owner 给 spender 授权 number=123
        bytes memory sig = _signFor(spender, newNumber, ownerPk);

        // 期望事件：old=0, new=123, by=spender
        vm.expectEmit(true, true, true, true);
        emit NumberChanged(0, newNumber, spender);

        // spender 调用
        vm.prank(spender);
        eip.permitStore(newNumber, sig);

        // 读值验证
        assertEq(eip.retrieve(), newNumber);
    }

    function test_signature_cannot_be_used_by_other_spender() public {
        uint256 newNumber = 777;

        // owner 只给 spender 授权
        bytes memory sig = _signFor(spender, newNumber, ownerPk);

        // other 试图拿着这份签名调用：因为 digest 里 spender=msg.sender，会验签失败
        vm.prank(other);
        vm.expectRevert(bytes("EIP712Storage: invalid signer"));
        eip.permitStore(newNumber, sig);
    }

    function test_signature_binds_number() public {
        // owner 签的是 number=100
        bytes memory sig = _signFor(spender, 100, ownerPk);

        // spender 想用这份签名写入 200：digest 不同 -> recover 出来的 signer != owner -> revert
        vm.prank(spender);
        vm.expectRevert(bytes("EIP712Storage: invalid signer"));
        eip.permitStore(200, sig);
    }

    function test_wrong_signer_reverts() public {
        uint256 newNumber = 456;

        // 用“非 owner”的私钥签（otherPk），即便参数对，也必须失败
        bytes memory sig = _signFor(spender, newNumber, otherPk);

        vm.prank(spender);
        vm.expectRevert(bytes("EIP712Storage: invalid signer"));
        eip.permitStore(newNumber, sig);
    }

    function test_replay_is_possible_in_this_demo() public {
        // 你这个合约没有 nonce/deadline，所以重放同一签名不会失败（演示用）
        uint256 newNumber = 999;
        bytes memory sig = _signFor(spender, newNumber, ownerPk);

        vm.prank(spender);
        eip.permitStore(newNumber, sig);
        assertEq(eip.retrieve(), newNumber);

        // 重放同一签名：不应 revert
        vm.prank(spender);
        eip.permitStore(newNumber, sig);
        assertEq(eip.retrieve(), newNumber);
    }
}
