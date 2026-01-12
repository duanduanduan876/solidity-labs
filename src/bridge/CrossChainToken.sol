// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * 简易跨链演示代币（Burn/Mint）
 * - 在当前链 bridge(): 从调用者余额烧毁 amount，并发出 Bridge 事件
 * - 在另一条链由桥的“管理员钱包”调用 mint(): 给用户铸造等量代币
 * 仅用于教学，不可用于生产
 */
contract CrossChainToken is ERC20, Ownable {
    event Bridge(address indexed user, uint256 amount);
    event Mint(address indexed to, uint256 amount);

    /**
     * @param name   代币名
     * @param symbol 代币符号
     * @param initSupply 初始发行量（注意 18 位精度）
     * 说明：为了符合 Burn/Mint 总量守恒的直觉，建议：
     *  - 源链部署时传入一个正数（例如 1_000_000 ether）
     *  - 目标链部署时传入 0（不预铸）
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        if (initSupply > 0) {
            _mint(msg.sender, initSupply);
        }
    }

    /// @notice 跨链桥出：从调用者余额烧毁，并发出事件
    function bridge(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Bridge(msg.sender, amount);
    }

    /// @notice 跨链桥入：仅 owner 可铸造
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Mint(to, amount);
    }
}