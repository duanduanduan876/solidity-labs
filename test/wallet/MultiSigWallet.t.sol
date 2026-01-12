// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { MultiSigWallet } from "src/wallet/MultiSigWallet.sol";

contract Receiver {
    uint256 public x;

    event GotETH(uint256 amount);

    function setX(uint256 v) external {
        x = v;
    }

    function revertAlways() external pure {
        revert("Receiver: revert");
    }

    receive() external payable {
        emit GotETH(msg.value);
    }
}

contract MultiSigWalletTest is Test {
    // 3 个 owner 的私钥（测试用）
    uint256 pk1 = 0xA11CE;
    uint256 pk2 = 0xB0B;
    uint256 pk3 = 0xCAFE;

    address o1;
    address o2;
    address o3;

    MultiSigWallet wallet;
    Receiver receiver;

    function setUp() public {
        // owner 地址
        o1 = vm.addr(pk1);
        o2 = vm.addr(pk2);
        o3 = vm.addr(pk3);

        // 关键：签名校验要求签名者地址严格递增，所以我们把 (addr,pk) 按 addr 排序
        (o1, pk1, o2, pk2, o3, pk3) = _sort3(o1, pk1, o2, pk2, o3, pk3);

        address[] memory owners = new address[](3); 
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;

        wallet = new MultiSigWallet(owners, 2);

        wallet = new MultiSigWallet(owners, 2);
        receiver = new Receiver();

        // 给 wallet 预存 ETH，方便测试 value 转账
        vm.deal(address(this), 10 ether);
        (bool ok,) = address(wallet).call{value: 2 ether}("");
        require(ok, "fund wallet failed");
    }

    // ===== helpers =====

    function _sort3(
        address a1, uint256 k1,
        address a2, uint256 k2,
        address a3, uint256 k3
    )
        internal
        pure
        returns (
            address b1, uint256 j1,
            address b2, uint256 j2,
            address b3, uint256 j3
        )
    {
        // bubble sort for 3
        b1 = a1; j1 = k1;
        b2 = a2; j2 = k2;
        b3 = a3; j3 = k3;

        if (b1 > b2) (b1, j1, b2, j2) = (b2, j2, b1, j1);
        if (b2 > b3) (b2, j2, b3, j3) = (b3, j3, b2, j2);
        if (b1 > b2) (b1, j1, b2, j2) = (b2, j2, b1, j1);
    }

    function _digest(address to, uint256 value, bytes memory data) internal view returns (bytes32 txHash, bytes32 digest) {
        uint256 n = wallet.nonce();
        uint256 cid = wallet.chainId();
        txHash = wallet.encodeTransactionData(to, value, data, n, cid);
        digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash));
    }

    function _sign2(bytes32 digest) internal returns (bytes memory sigs) {
        // threshold=2，签 o1、o2（已保证地址升序）
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, digest);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk2, digest);

        sigs = bytes.concat(
            abi.encodePacked(r1, s1, v1),
            abi.encodePacked(r2, s2, v2)
        );
    }

    // ===== tests =====

    function test_Constructor_InvalidThreshold_Zero_Reverts() public {
        address[] memory owners = new address[](1);
        owners[0] = o1;
        vm.expectRevert(bytes("WTF5002"));
        new MultiSigWallet(owners, 0);
    }

    function test_Constructor_InvalidThreshold_TooHigh_Reverts() public {
        address[] memory owners = new address[](1);
        owners[0] = o1;
        vm.expectRevert(bytes("WTF5001"));
        new MultiSigWallet(owners, 2);
    }

    function test_Constructor_DuplicateOwner_Reverts() public {
        address[] memory owners = new address[](2);
        owners[0] = o1;
        owners[1] = o1;
        vm.expectRevert(bytes("WTF5003"));
        new MultiSigWallet(owners, 1);
    }

    function test_ExecTransaction_Success_SetX() public {
        bytes memory data = abi.encodeWithSelector(receiver.setX.selector, 42);

        (, bytes32 digest) = _digest(address(receiver), 0, data);
        bytes memory sigs = _sign2(digest);

        bool ok = wallet.execTransaction(address(receiver), 0, data, sigs);
        assertTrue(ok);
        assertEq(receiver.x(), 42);
        assertEq(wallet.nonce(), 1);
    }

    function test_ExecTransaction_Success_SendETH() public {
        uint256 beforeRecv = address(receiver).balance;
        bytes memory data = "";

        (, bytes32 digest) = _digest(address(receiver), 0.3 ether, data);
        bytes memory sigs = _sign2(digest);

        wallet.execTransaction(address(receiver), 0.3 ether, data, sigs);
        assertEq(address(receiver).balance, beforeRecv + 0.3 ether);
    }

    function test_ReplayProtection_SameSignatures_FailAfterNonceChanges() public {
        bytes memory data = abi.encodeWithSelector(receiver.setX.selector, 7);

        // 第一次：用 nonce=0 签名，成功
        (, bytes32 digest1) = _digest(address(receiver), 0, data);
        bytes memory sigs1 = _sign2(digest1);
        wallet.execTransaction(address(receiver), 0, data, sigs1);
        assertEq(receiver.x(), 7);

        // 第二次：重放同一 signatures（nonce 已变），应失败（签名不再匹配）
        vm.expectRevert(bytes("WTF5007"));
        wallet.execTransaction(address(receiver), 0, data, sigs1);
    }

    function test_CheckSignatures_RevertIfSignatureLengthTooShort() public {
        bytes memory data = abi.encodeWithSelector(receiver.setX.selector, 1);
        (, bytes32 digest) = _digest(address(receiver), 0, data);

        // 只给 1 个签名 => 65 bytes < 2*65 => WTF5006
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk1, digest);
        bytes memory sigs = abi.encodePacked(r, s, v);

        vm.expectRevert(bytes("WTF5006"));
        wallet.execTransaction(address(receiver), 0, data, sigs);
    }

    function test_CheckSignatures_RevertIfUnsortedSigners() public {
        bytes memory data = abi.encodeWithSelector(receiver.setX.selector, 2);
        (, bytes32 digest) = _digest(address(receiver), 0, data);

        // 故意把签名顺序倒过来：o2 在前，o1 在后 => currentOwner > lastOwner 失败
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, digest);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(pk2, digest);

        bytes memory sigs = bytes.concat(
            abi.encodePacked(r2, s2, v2),
            abi.encodePacked(r1, s1, v1)
        );

        vm.expectRevert(bytes("WTF5007"));
        wallet.execTransaction(address(receiver), 0, data, sigs);
    }

    function test_CheckSignatures_RevertIfNonOwnerSigner() public {
        bytes memory data = abi.encodeWithSelector(receiver.setX.selector, 3);
        (, bytes32 digest) = _digest(address(receiver), 0, data);

        uint256 badPk = 0xDEAD;
        address badAddr = vm.addr(badPk);
        // 把 (badAddr,badPk) 和 (o1,pk1) 排序后拼在前两位，确保校验到非 owner
        if (badAddr < o1) {
            (uint8 vBad, bytes32 rBad, bytes32 sBad) = vm.sign(badPk, digest);
            (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, digest);
            bytes memory sigs = bytes.concat(
                abi.encodePacked(rBad, sBad, vBad),
                abi.encodePacked(r1, s1, v1)
            );
            vm.expectRevert(bytes("WTF5007"));
            wallet.execTransaction(address(receiver), 0, data, sigs);
        } else {
            (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(pk1, digest);
            (uint8 vBad, bytes32 rBad, bytes32 sBad) = vm.sign(badPk, digest);
            bytes memory sigs = bytes.concat(
                abi.encodePacked(r1, s1, v1),
                abi.encodePacked(rBad, sBad, vBad)
            );
            vm.expectRevert(bytes("WTF5007"));
            wallet.execTransaction(address(receiver), 0, data, sigs);
        }
    }

    function test_ExecTransaction_RevertsWhenCallFails() public {
        bytes memory data = abi.encodeWithSelector(receiver.revertAlways.selector);

        (, bytes32 digest) = _digest(address(receiver), 0, data);
        bytes memory sigs = _sign2(digest);

        vm.expectRevert(bytes("WTF5004"));
        wallet.execTransaction(address(receiver), 0, data, sigs);
    }
}
