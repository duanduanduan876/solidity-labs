// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title Proxy
 * @notice 极简代理：把所有外部调用通过 fallback 委托给 implementation。
 *         注意：Proxy 与 Logic 的状态变量布局必须一致（至少前若干槽一致），否则会产生存储冲突。
 */
contract Proxy {
    // slot0 —— 与 Logic 的第一个状态变量对齐，避免插槽冲突
    address public implementation;

    constructor(address implementation_) {
        implementation = implementation_;
    }

    // 可接收 ETH（可选）
    //如果你发送的是 空 calldata（0x），且带 ETH，那么会进 receive()；没有 receive() 才会用 fallback。
    receive() external payable {}

    /**
     * @dev 回调函数，将本合约的调用 delegatecall 给 implementation
     * 使用内联汇编实现“有返回值的 fallback”。
     */
    fallback() external payable {
        address _implementation = implementation;
        assembly {
            // 1) 把 calldata 拷贝到内存起始位置 0
            calldatacopy(0, 0, calldatasize())

            // 2) delegatecall(全部 gas, 目标地址, 输入内存起点, 输入长度, 输出内存起点, 输出长度)
            //    输出区域我们先给 0, 0，随后用 returndatacopy 取回真实返回值。
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // 3) 把 returndata 拷贝回内存
            returndatacopy(0, 0, returndatasize())

            // 4) 成功则 return，失败则 revert
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

/**
 * @title Logic
 * @notice 演示用逻辑合约：与 Proxy 的 slot0 对齐（implementation），再放 x。
 *         直接调用 Logic.increment() 会返回 100（因为这里 x=99）；
 *         通过 Proxy 调用时，读到的是 Proxy 的 slot1（默认为 0），所以返回 1。
 */
contract Logic {
    // 与 Proxy 对齐的占位，避免插槽冲突（slot0）
    address public implementation;

    // slot1：本合约自己的 x，初始化为 99
    uint256 public x = 99;

    event CallSuccess();

    // 读当前上下文存储中的 x 并 +1 后返回
    function increment() external payable returns (uint256) {
        emit CallSuccess();
        return x + 1;
    }

    // 读当前上下文存储中的 x（用于观察直调 vs 代理下的 x 值差异）
    function readX() external view returns (uint256) {
        return x;
    }
}

/**
 * @title Caller
 * @notice 调用 Proxy 的小帮手：用 call/staticcall 演示通过代理去调用 Logic 的函数。
 */
contract Caller {
    address public proxy;

    constructor(address proxy_) {
        proxy = proxy_;
    }

    // 通过代理调用 increment()，返回 uint
    function increment() external returns (uint256) {
        (bool ok, bytes memory data) = proxy.call(abi.encodeWithSignature("increment()"));
        require(ok, "proxy call failed");
        return abi.decode(data, (uint256));
    }

    // 通过代理只读 readX()，返回 uint
    function readX() external view returns (uint256) {
        (bool ok, bytes memory data) = proxy.staticcall(abi.encodeWithSignature("readX()"));
        require(ok, "proxy staticcall failed");
        return abi.decode(data, (uint256));
    }
}

//Proxy delegatecall 到 Logic：在 Logic 代码里看到的 msg.sender 仍然是 Caller（因为 delegatecall 保留的是“上一帧的 msg.sender”，
//上一帧是 Proxy，而 Proxy 的 msg.sender 是 Caller）