// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ===== 需要的极简接口 =====
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Factory {
    function getPair(address, address) external view returns (address);
}

// Uniswap V3 Router：主网 0xE592...1564，使用 exactOutputSingle
interface ISwapRouterV3 {
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;              // 主网常用 3000
        address recipient;
        uint256 deadline;
        uint256 amountOut;       // 目标输出（我们要的 DAI）
        uint256 amountInMaximum; // 愿意花费的最多 WETH
        uint160 sqrtPriceLimitX96;
    }
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
}

contract UniswapV2FlashloanOppositeRepay {
    event FlashStart(uint256 wethBorrow);
    event RepayWithDAI(uint256 daiNeeded, uint256 wethSpent, uint256 daiSent);
    event Profit(uint256 wethLeft, uint256 daiLeft);

    // ===== 主网地址（如在非主网，请改为构造传参）=====
    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant V3_ROUTER  = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap V3 SwapRouter
    uint24  constant V3_POOL_FEE = 3000; // DAI/WETH 常见费率

    IUniswapV2Pair public immutable pair; // DAI/WETH V2 Pair

    constructor() {
        address p = IUniswapV2Factory(V2_FACTORY).getPair(DAI, WETH);
        require(p != address(0), "pair not found");
        pair = IUniswapV2Pair(p);
        // 断言 token0/token1 顺序（主网 DAI/WETH：token0=DAI, token1=WETH）
        require(pair.token0() == DAI && pair.token1() == WETH, "unexpected token order");
    }

    // 借 WETH（token1），走回调
    function flashloan(uint256 wethAmount) external {
        emit FlashStart(wethAmount);
        bytes memory data = abi.encode(address(this), WETH, wethAmount, uint8(1)); // flag=1 表示“用对立币还”
        pair.swap(0, wethAmount, address(this), data);
    }

    // ===== Uniswap V2 回调 =====
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        require(msg.sender == address(pair), "not pair");
        require(sender == address(this), "bad sender");
        
        //解码出来，谁调用的，借的什么，借了多少，同币还还是对立币还
        (address initiator, address tokenBorrow, uint256 amountBorrow, uint8 repayMode)
            = abi.decode(data, (address, address, uint256, uint8));

        require(initiator == address(this), "bad initiator");
        require(tokenBorrow == WETH, "borrow != WETH");
        require(amount0 == 0 && amount1 == amountBorrow, "amount mismatch");

        // ========= 你的策略（套利/清算）写在这里 =========
        // 示例：这里假装你已经通过别处操作赚到了更多 WETH
        //       如果需要，你也可以在这里调用其他 DEX/清算合约
        // ==============================================

        if (repayMode == 0) {
            // 备用：同币还款（WETH 本金+fee），不演示
            _repaySameToken(amountBorrow);
        } else {
            // 重点：对立币（DAI）还款
            _repayWithOppositeToken_DAI(amountBorrow);
        }

        // 留在合约里的就是利润（WETH/DAI）
        emit Profit(IERC20(WETH).balanceOf(address(this)), IERC20(DAI).balanceOf(address(this)));
    }

    // ===== 用 WETH 直接还（老写法，备用）=====
    function _repaySameToken(uint256 amountBorrow) internal {
        // V2 传统手续费写法（向上取整）
        uint256 fee = (amountBorrow * 3) / 997 + 1;
        uint256 repay = amountBorrow + fee;
        require(IERC20(WETH).balanceOf(address(this)) >= repay, "not enough WETH");
        IERC20(WETH).transfer(address(pair), repay);
    }

    // ===== 用“对立币 DAI”来还 =====
    function _repayWithOppositeToken_DAI(uint256 amount1Out /*借的 WETH*/) internal {
        // 1) 读取 V2 储备
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        // 确认 token0=DAI, token1=WETH
        // 2) 计算“最小需要打回的 DAI（token0In）”，使 K 检查通过（含 0.3% 手续费）
        //    amountIn = floor( reserveIn * amountOut * 1000 / ((reserveOut - amountOut) * 997) ) + 1
        //    这里：reserveIn = r0(DAI), amountOut = amount1Out(WETH), reserveOut = r1(WETH)
        uint256 daiNeeded = (uint256(r0) * amount1Out * 1000) / ( (uint256(r1) - amount1Out) * 997 ) + 1;

        // 3) 现有 DAI 余额
        uint256 daiBal = IERC20(DAI).balanceOf(address(this));
        if (daiBal < daiNeeded) {
            // 需要把一部分 WETH 换成 DAI（走 V3 Router，避开当前 V2 Pair 的 lock）
            uint256 daiShort = daiNeeded - daiBal;
            uint256 wethBal = IERC20(WETH).balanceOf(address(this));
            require(wethBal > 0, "no WETH to swap");

            // 选择“exactOutputSingle”：精确输出 DAI，最小化 WETH 花费
            IERC20(WETH).approve(V3_ROUTER, type(uint256).max);
            ISwapRouterV3.ExactOutputSingleParams memory p = ISwapRouterV3.ExactOutputSingleParams({
                tokenIn: WETH,
                tokenOut: DAI,
                fee: V3_POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: daiShort,
                amountInMaximum: wethBal,          // 上限用当前 WETH 余额（你可改小，控制滑点）
                sqrtPriceLimitX96: 0
            });
            uint256 wethSpent = ISwapRouterV3(V3_ROUTER).exactOutputSingle(p);
            emit RepayWithDAI(daiNeeded, wethSpent, daiShort);
        }

        // 4) 直接把 DAI 打回原 V2 Pair，完成“对立币还款”
        IERC20(DAI).transfer(address(pair), daiNeeded);
        // 注意：不需要再给 WETH；K 检查会用余额差 + 997/1000 的整数式验证
    }
}