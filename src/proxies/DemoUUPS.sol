// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * 极简教学版 UUPS 代理
 * - 仅用于学习，勿上生产
 */
 //
contract DemoUUPSProxy {
    // 与逻辑合约保持相同的存储布局（顺序/类型完全一致）
    address public implementation; // 逻辑合约地址
    address public admin;          // 管理员
    string  public words;          // 测试用字符串

    event Upgraded(address indexed newImplementation);

    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    // 可选：改管理员，便于演示权限（不是 UUPS 必选内容）
    function changeAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin");
        admin = newAdmin;
    }

    receive() external payable {}

    // 回退函数：把调用委托给当前 implementation
    fallback() external payable {
        address impl = implementation;
        assembly {
            // 拷贝 calldata
            calldatacopy(0x0, 0x0, calldatasize())
            // delegatecall(gas, impl, in, insize, out, outsize)
            let result := delegatecall(gas(), impl, 0x0, calldatasize(), 0, 0)
            // 拷贝 returndata
            let size := returndatasize()
            returndatacopy(0x0, 0x0, size)
            // 根据 result 返回/回滚
            switch result
            case 0 { revert(0x0, size) }
            default { return(0x0, size) }
        }
    }
}

/**
 * 旧逻辑合约（DemoUUPS1）
 * - 与 Proxy 完全一致的存储布局
 * - 包含升级函数 upgrade(address)（UUPS 的关键）
 */
contract DemoUUPS1 {
    // 存储布局必须与 Proxy 完全一致
    address public implementation;
    address public admin;
    string  public words;

    event WordsChanged(string newWords);
    event Upgraded(address indexed newImplementation);

    // 示例业务函数：把 words 写成 "old"
    function foo() external {
        words = "old";
        emit WordsChanged(words);
    }

    // 升级函数（在代理上下文里执行），仅 admin 可调
    function upgrade(address newImplementation) external {
        require(msg.sender == admin, "only admin");
        implementation = newImplementation;
        emit Upgraded(newImplementation); // 事件地址会显示为 Proxy 地址（delegatecall 的上下文）
    }

    // 便于确认当前逻辑版本
    function version() external pure returns (string memory) {
        return "DemoUUPS1";
    }
}

/**
 * 新逻辑合约（DemoUUPS2）
 * - 同样包含 upgrade（否则升级到这里会“堵死”后续升级通道）
 */
contract DemoUUPS2 {
    address public implementation;
    address public admin;
    string  public words;

    event WordsChanged(string newWords);
    event Upgraded(address indexed newImplementation);

    // 示例业务函数：把 words 写成 "new"
    function foo() external {
        words = "new";
        emit WordsChanged(words);
    }

    function upgrade(address newImplementation) external {
        require(msg.sender == admin, "only admin");
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function version() external pure returns (string memory) {
        return "DemoUUPS2";
    }
}