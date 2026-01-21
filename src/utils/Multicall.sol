// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Interview-ready Multicall: per-call ETH value, optional staticcall,
///         allowFailure, target code check, value accounting + refund, rich errors.
contract MulticallPlus {
    // ====== Input / Output Types ======

    /// @dev One item in the batch.
    struct Call {
        address target;       // target contract
        uint256 value;        // ETH to send with this call
        bool allowFailure;    // if false and call fails -> revert whole batch
        bool isStatic;        // true => staticcall, false => call
        bytes callData;       // encoded calldata (selector + args)
    }

    struct Result {
        bool success;         // low-level call success flag
        bytes returnData;     // raw returndata (success: encoded return values, fail: revert data)
    }

    // ====== Custom Errors (cheaper + more informative than revert(string)) ======

    error TargetHasNoCode(uint256 index, address target);
    error InsufficientValue(uint256 required, uint256 provided);
    error CallFailed(uint256 index, address target, bytes revertData);
    error RefundFailed(address to, uint256 amount);

    // ====== Main Batch Executor ======

    /// @notice Execute a batch. Supports mixing call/staticcall and per-call ETH value.
    /// @dev msg.value must cover sum(calls[i].value). Extra ETH is refunded.
    function multicall(Call[] calldata calls) external payable returns (Result[] memory results) {
        uint256 length = calls.length;
        results = new Result[](length);

        uint256 spent = 0;

        for (uint256 i = 0; i < length; ) {
            Call calldata c = calls[i];

            // Guard: target must be a contract
            if (c.target.code.length == 0) {
                revert TargetHasNoCode(i, c.target);
            }

            // 约束：staticcall 不许带 value
     if (c.isStatic && c.value != 0) {
    revert InsufficientValue(c.value, 0);
        }

    bool ok;
    bytes memory ret;

        if (c.isStatic) {
          (ok, ret) = c.target.staticcall(c.callData);
        } else {
       (ok, ret) = c.target.call{value: c.value}(c.callData);
          if (ok) {
        spent += c.value; // 只在成功时计入真正花掉的 ETH
    }
}

            results[i] = Result(ok, ret);

            // Failure policy
            if (!c.allowFailure && !ok) {
                revert CallFailed(i, c.target, ret);
            }

            unchecked { ++i; }
        }

        // Refund extra ETH, if any
        uint256 refund = msg.value - spent;
        if (refund != 0) {
            (bool s, ) = msg.sender.call{value: refund}("");
            if (!s) revert RefundFailed(msg.sender, refund);
        }
    }

    // ====== Convenience Read Helpers (often asked in interviews) ======

    function getBlockNumber() external view returns (uint256) {
        return block.number;
    }

    function getEthBalance(address who) external view returns (uint256) {
        return who.balance;
    }

    // Allow receiving ETH (e.g., refunds, direct transfers)
    receive() external payable {}
}