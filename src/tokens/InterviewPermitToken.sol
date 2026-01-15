// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title InterviewPermitToken
 * @notice 面试/学习用：手写实现 EIP-2612 permit（不继承 OZ ERC20Permit）。
 */
contract InterviewPermitToken is ERC20, IERC20Permit, EIP712, Ownable {
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 private constant _PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    mapping(address => uint256) private _nonces;

    error ExpiredDeadline();
    error ZeroAddress();
    error InvalidSpender();
    error InvalidSignature();

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    )
        ERC20(name_, symbol_)
        EIP712(name_, "1")
        Ownable(msg.sender)
    {
        if (initialSupply > 0) _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        if (owner == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert InvalidSpender();
        if (block.timestamp > deadline) revert ExpiredDeadline();

        uint256 nonce = _nonces[owner];

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, v, r, s);
        if (signer != owner) revert InvalidSignature();

        unchecked { _nonces[owner] = nonce + 1; }
        _approve(owner, spender, value);
    }

    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
}
