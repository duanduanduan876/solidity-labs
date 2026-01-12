// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Multicall {
    //调用结构体
    struct Call {
        address target;//MCERC20地址
        bool allowFailure;
        bytes callData;//函数的calldata
    }
    //结果结构体
    struct Result {
        bool success;
        bytes returnData;
    }
    //call结构体组成的数组，返回的是Result结构体数组
    function multicall(Call[] calldata calls) public returns (Result[] memory) {
        //获取传入的calls数组的长度，存储在变量length中
        uint256 length = calls.length;
        Result[] memory results = new Result[](length);  // 创建结果数组
        
        for (uint256 i = 0; i < length; i++) {
            //获取传入的calls数组的第i个元素，存储在变量calli中
            //calli 是一个临时变量，用于在循环中存储当前的调用信息（即 `calls[i]`）
            //所以，calli 就是当前循环处理的单个 Call 结构体
            //从calldata中的`calls`数组里取出第i个元素，并将其作为calldata位置的一个引用赋值给变量`calli`
            Call calldata calli = calls[i];  // 获取当前调用，记忆位置信息
            
            // 直接执行调用并存储结果，使用提供的调用数据（`calli.callData`）调用目标合约（`calli.target`）
            //相当于根据位置找书的位置
            (bool success, bytes memory returnData) = calli.target.call(calli.callData);
            
            // 将结果直接存入数组
            results[i] = Result(success, returnData);
            
            // 错误检查：如果不允许失败且实际失败，则回滚
            if (!calli.allowFailure && !success) {
                revert("Multicall: call failed");
            }
        }
        
        return results;  // 返回所有结果
    }
}