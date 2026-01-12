// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * 极简 ERC20（教学用），含 mint，允许任意人增发便于测试。
 * 注意：生产中严禁这样写！
 */
contract ERC20Lite {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function _transfer(address from, address to, uint value) internal {
        require(to != address(0), "transfer to zero");
        require(balanceOf[from] >= value, "insufficient balance");
        unchecked {
            balanceOf[from] -= value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        uint allowed = allowance[from][msg.sender];
        require(allowed >= value, "insufficient allowance");
        if (allowed != type(uint).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function _mint(address to, uint value) internal {
        require(to != address(0), "mint to zero");
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    // 教学方便：任何人都能增发测试币
    function mint(address to, uint value) external {
        _mint(to, value);
    }
}

/**
 * 两个测试代币：COLA & USD
 */
contract COLAToken is ERC20Lite {
    constructor() ERC20Lite("COLA", "COLA") {}
}

contract USDToken is ERC20Lite {
    constructor() ERC20Lite("USD Token", "USD") {}
}

/**
 * SimpleSwap：恒定积 AMM，LP 代币也用 ERC20Lite 表示（名字 SS-LP）
 * 注意：仅教学，未计费、未防重入、未做路由、未考虑各种边界，勿用于生产。
 */
contract SimpleSwap is ERC20Lite {
    // 交易对代币
    ERC20Lite public token0; // 建议部署时传 COLA
    ERC20Lite public token1; // 建议部署时传 USD

    // 储备量快照（便于观察），真实储备以 balanceOf(This) 为准
    uint public reserve0;
    uint public reserve1;

    // 事件
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1);
    event Swap(address indexed sender, uint amountIn, address tokenIn, uint amountOut, address tokenOut);

    constructor(ERC20Lite _token0, ERC20Lite _token1)
        ERC20Lite("SimpleSwap LP", "SS-LP")
    {
        token0 = _token0;
        token1 = _token1;
    }

    // 工具函数
    function min(uint x, uint y) internal pure returns (uint z) { z = x < y ? x : y; }

    // Babylonian sqrt
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getReserves() external view returns (uint _reserve0, uint _reserve1) {
        _reserve0 = token0.balanceOf(address(this));
        _reserve1 = token1.balanceOf(address(this));
    }

    // ===== 流动性：添加 =====
    // 首次：L = sqrt(dx * dy)
    // 非首次：L = min(dx/reserve0, dy/reserve1) * totalSupply
    function addLiquidity(uint amount0Desired, uint amount1Desired) external returns (uint liquidity) {
        require(amount0Desired > 0 && amount1Desired > 0, "amounts zero");

        // 先收币（需事先 approve）
        require(token0.transferFrom(msg.sender, address(this), amount0Desired), "t0 transferFrom fail");
        require(token1.transferFrom(msg.sender, address(this), amount1Desired), "t1 transferFrom fail");

        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = sqrt(amount0Desired * amount1Desired);
        } else {
            // 注意：这里会把不按比例多转进来的那部分“留在池子里”（教学简化）
            uint liq0 = amount0Desired * _totalSupply / reserve0;
            uint liq1 = amount1Desired * _totalSupply / reserve1;
            liquidity = min(liq0, liq1);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        // 更新储备量快照
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        // 给 LP 铸份额
        _mint(msg.sender, liquidity);
        emit Mint(msg.sender, amount0Desired, amount1Desired);
    }

    // ===== 流动性：移除 =====
    // 退回数量 = (liquidity / totalSupply) * 当前储备
    function removeLiquidity(uint liquidity) external returns (uint amount0, uint amount1) {
        require(liquidity > 0, "zero liq");
        uint _totalSupply = totalSupply;
        require(_totalSupply > 0, "no LP");

        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        // 销毁 LP
        // （本合约就是 LP 代币合约，直接减）
        require(balanceOf[msg.sender] >= liquidity, "not enough LP");
        unchecked {
            balanceOf[msg.sender] -= liquidity;
            totalSupply -= liquidity;
        }
        emit Transfer(msg.sender, address(0), liquidity);

        // 退币
        require(token0.transfer(msg.sender, amount0), "t0 transfer fail");
        require(token1.transfer(msg.sender, amount1), "t1 transfer fail");

        // 更新储备快照
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Burn(msg.sender, amount0, amount1);
    }

    // ===== 定价公式：给定输入求输出 =====
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, "INSUFFICIENT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        amountOut = amountIn * reserveOut / (reserveIn + amountIn);
    }

    // ===== 交换 =====
    // @param tokenIn：传入代币地址（必须是 token0 或 token1）
    // @param amountOutMin：最小可接受输出（滑点保护），注意这里用 ">"（严格大于）
    function swap(uint amountIn, address tokenIn, uint amountOutMin)
        external
        returns (uint amountOut, address tokenOut)
    {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(tokenIn == address(token0) || tokenIn == address(token1), "INVALID_TOKEN");

        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        if (tokenIn == address(token0)) {
            tokenOut = address(token1);
            amountOut = getAmountOut(amountIn, bal0, bal1);
            require(amountOut > amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
            require(token0.transferFrom(msg.sender, address(this), amountIn), "t0 tfFrom fail");
            require(token1.transfer(msg.sender, amountOut), "t1 transfer fail");
        } else {
            tokenOut = address(token0);
            amountOut = getAmountOut(amountIn, bal1, bal0);
            require(amountOut > amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
            require(token1.transferFrom(msg.sender, address(this), amountIn), "t1 tfFrom fail");
            require(token0.transfer(msg.sender, amountOut), "t0 transfer fail");
        }

        // 更新储备快照
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Swap(msg.sender, amountIn, tokenIn, amountOut, tokenOut);
    }
}