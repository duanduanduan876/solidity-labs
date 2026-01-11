// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * 简单可升级合约（教学演示用，勿用于生产）
 * 说明：
 * - 通过 admin 可调用 upgrade() 更换 implementation 地址，从而改变逻辑。
 * - fallback 使用 delegatecall 将外部调用转发给逻辑合约。
 * - 逻辑合约与代理合约的状态变量布局（顺序和类型）必须保持一致，避免“插槽冲突”。
 */
contract SimpleUpgrade {
    // 注意：这三个状态变量的顺序和类型将决定存储布局
    address public implementation; // 逻辑合约地址
    address public admin;          // 管理员地址
    string  public words;          // 由逻辑合约中的函数改变

    // 构造：初始化 admin 和逻辑合约地址
    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    // 升级：仅 admin 可调用
    function upgrade(address newImplementation) external {
        require(msg.sender == admin, "not admin");
        implementation = newImplementation;
    }

    // 可选：接收 ETH（本例不做业务用途，仅示范）
    receive() external payable {}

    /**
     * fallback：将调用委托给当前 implementation
     * 教学简化版：不用内联汇编，不处理返回值编解码，但至少保证失败时回滚。
     */
    fallback() external payable {
        (bool ok, ) = implementation.delegatecall(msg.data);
        require(ok, "delegatecall failed");
    }
}

/**
 * 逻辑合约 v1
 * - 状态变量布局与 Proxy 一致（顺序、类型都要一样）
 * - foo(): 将 words 设置为 "old"
 */
contract Logic1 {
    // 必须与 Proxy 的布局一致
    address public implementation; 
    address public admin; 
    string  public words; 

    // 函数选择器（selector）为 0xc2985578（keccak256("foo()")[0:4]）
    function foo() public {
        words = "old";
    }
}

/**
 * 逻辑合约 v2
 * - 布局仍与 Proxy 一致
 * - foo(): 将 words 设置为 "new"
 */
contract Logic2 {
    // 必须与 Proxy 的布局一致
    address public implementation; 
    address public admin; 
    string  public words; 

    function foo() public {
        words = "new";
    }
}