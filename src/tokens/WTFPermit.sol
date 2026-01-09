// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// 下面保持你原来的合约内容不变
contract WTFPermitToken is ERC20, ERC20Permit {
    constructor(uint256 initialSupply)
        ERC20("WTFPermit", "WTFP")
        ERC20Permit("WTFPermit")
    {
        _mint(msg.sender, initialSupply);
    }

    function faucetMint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC20PermitMinimal {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);
}

contract PermitSpender {
    event Pulled(address indexed token, address indexed from, address indexed to, uint256 value);

    function permitThenTransferFrom(
        address token,
        address owner,
        address to,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20PermitMinimal(token).permit(owner, address(this), value, deadline, v, r, s);

        bool ok = IERC20Minimal(token).transferFrom(owner, to, value);
        require(ok, "transferFrom failed");

        emit Pulled(token, owner, to, value);
    }
}
