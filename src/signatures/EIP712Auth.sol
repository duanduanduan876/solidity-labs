// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * EIP712Storage
 * - owner（部署者）使用 EIP-712 为 {spender, number} 授权
 * - spender 携带签名调用 permitStore(number, signature) 完成写入
 * 提示：演示代码无 nonce/deadline，存在可重放风险，生产请加防重放设计
 */
contract EIP712Storage {
    using ECDSA for bytes32;

    // EIP-712 类型哈希
    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant STORAGE_TYPEHASH =
        keccak256("Storage(address spender,uint256 number)");

    // 域分隔符（部署时固化）
    bytes32 private immutable _domainSeparator;

    // 所有者（签名者）
    address public immutable owner;

    // 被存储的值
    uint256 private _number;

    event NumberChanged(uint256 indexed oldValue, uint256 indexed newValue, address indexed by);

    constructor() {
        _domainSeparator = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("EIP712Storage")), // name
                keccak256(bytes("1")),             // version
                block.chainid,                     // chainId
                address(this)                      // verifyingContract
            )
        );
        owner = msg.sender;
    }

    // 读取 number
    function retrieve() external view returns (uint256) {
        return _number;
    }

    // 调试：查看域分隔符
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator;
    }

    // 调试：返回 EIP-712 最终 digest（EIP-191 前缀 0x1901 + 域 + 结构体哈希）
    function hashTypedData(address spender, uint256 number) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(STORAGE_TYPEHASH, spender, number));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, structHash));
    }

    /**
     * 核心：spender 携带 owner 的签名来修改 number
     * - 签名者必须是 owner
     * - 签名消息中 spender 必须等于 msg.sender
     * - 签名消息中 number 必须等于传参 newNumber
     */
    function permitStore(uint256 newNumber, bytes calldata signature) external {
        bytes32 digest = hashTypedData(msg.sender, newNumber);
        address signer = digest.recover(signature); // 直接用 bytes 签名恢复
        require(signer == owner, "EIP712Storage: invalid signer");
        uint256 old = _number;
        _number = newNumber;
        emit NumberChanged(old, newNumber, msg.sender);
    }
}