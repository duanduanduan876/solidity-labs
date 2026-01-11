// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * 透明代理（教学版）
 * 核心规则：
 * - 非管理员：可通过 fallback/receive 走 delegatecall 到逻辑合约。
 * - 管理员：禁止走 fallback/receive（避免“选择器冲突”误触升级等函数）。
 * - 仅管理员可 upgrade()。
 */
contract TransparentProxy {
    // 与 Logic 保持相同的插槽顺序与类型（简化教学，不走 EIP-1967）
    address public implementation; // logic 合约地址
    address public admin;          // 管理员
    string  public words;          // 由逻辑合约改写

    event Upgraded(address indexed newImplementation);

    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    // 仅管理员可升级
    function upgrade(address newImplementation) external {
        require(msg.sender == admin, "TransparentProxy: bushi admin");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    // ---- 内部委托逻辑，复用于 fallback/receive ----
    function _delegate() internal {
        require(msg.sender != admin, "TransparentProxy: admin cannot call logic");
        (bool ok, bytes memory ret) = implementation.delegatecall(msg.data);
        if (!ok) {
            // revert 冒泡
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        // return 冒泡
        assembly {
            return(add(ret, 0x20), mload(ret))
        }
    }

    fallback() external payable { _delegate(); }
    receive() external payable { _delegate(); }
}

// 旧逻辑合约
contract TPLogic1 {
    // 与 Proxy 完全一致的插槽布局（顺序与类型）
    address public implementation;
    address public admin;
    string  public words;

    // 选择器：0xc2985578（"foo()" 的前 4 字节）
    function foo() public {
        words = "old";
    }

    // 只是为了在调试里辨识版本
    function version() external pure returns (string memory) {
        return "Logic1";
    }
}

// 新逻辑合约
contract TPLogic2 {
    address public implementation;
    address public admin;
    string  public words;

    // 相同选择器 0xc2985578
    function foo() public {
        words = "new";
    }

    function version() external pure returns (string memory) {
        return "Logic2";
    }
}