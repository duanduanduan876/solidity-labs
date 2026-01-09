// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {WTFPermitToken, PermitSpender} from "../../src/tokens/WTFPermit.sol";

contract PermitTest is Test {
    // 测试用私钥（别用真钱包）
    uint256 internal ownerPk = 0xA11CE;
    uint256 internal otherPk = 0xB0B;

    address internal owner;
    address internal other;

    WTFPermitToken internal token;
    PermitSpender internal spender;

    // EIP-2612 Permit typehash
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        owner = vm.addr(ownerPk);
        other = vm.addr(otherPk);

        // 让 owner 成为 token 部署者，这样初始供应就 mint 给 owner
        vm.prank(owner);
        token = new WTFPermitToken(1_000_000e18);

        spender = new PermitSpender();
    }

    function _digest(uint256 value, uint256 deadline) internal view returns (bytes32) {
        uint256 nonce = token.nonces(owner);
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                address(spender),
                value,
                nonce,
                deadline
            )
        );

        // EIP-712 digest = keccak256("\x19\x01" || domainSeparator || structHash)
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }

    function test_permit_then_transferFrom_ok() public {
        uint256 value = 123e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _digest(value, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        // caller 可以是任何人（这里就是测试合约本身），不影响
        spender.permitThenTransferFrom(address(token), owner, other, value, deadline, v, r, s);

        assertEq(token.balanceOf(other), value);
        assertEq(token.balanceOf(owner), 1_000_000e18 - value);

        // nonce 必须 +1（防重放的核心证据）
        assertEq(token.nonces(owner), 1);

        // allowance 用完会变回 0（因为 transferFrom 消耗掉）
        assertEq(token.allowance(owner, address(spender)), 0);
    }

    function test_replay_should_revert() public {
        uint256 value = 10e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _digest(value, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        spender.permitThenTransferFrom(address(token), owner, other, value, deadline, v, r, s);

        // 同一份签名重放：nonce 已变，permit 应该直接 revert
        vm.expectRevert();
        spender.permitThenTransferFrom(address(token), owner, other, value, deadline, v, r, s);
    }

    function test_expired_should_revert() public {
        uint256 value = 1e18;
        uint256 deadline = block.timestamp - 1; // 已过期

        bytes32 digest = _digest(value, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        vm.expectRevert();
        spender.permitThenTransferFrom(address(token), owner, other, value, deadline, v, r, s);
    }

    function test_wrong_value_should_revert() public {
        uint256 signedValue = 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _digest(signedValue, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, digest);

        // 用签名去授权 1e18，但实际想拉 2e18：签名绑定 value，应 revert
        vm.expectRevert();
        spender.permitThenTransferFrom(address(token), owner, other, 2e18, deadline, v, r, s);
    }

    function test_wrong_signer_should_revert() public {
        uint256 value = 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _digest(value, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPk, digest); // 非 owner 签名

        vm.expectRevert();
        spender.permitThenTransferFrom(address(token), owner, other, value, deadline, v, r, s);
    }
}
