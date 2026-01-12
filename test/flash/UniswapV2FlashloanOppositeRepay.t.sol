// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { UniswapV2FlashloanOppositeRepay } from "src/flash/UniswapV2FlashloanOppositeRepay.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: balance");
        unchecked {
            balanceOf[msg.sender] -= amount;
            balanceOf[to] += amount;
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "ERC20: allowance");
        require(balanceOf[from] >= amount, "ERC20: balance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
        return true;
    }
}

contract MockV2Pair {
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    function sync() external {
        reserve0 = uint112(MockERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(MockERC20(token1).balanceOf(address(this)));
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(amount0Out == 0 || amount1Out == 0, "only one side out");

        uint112 _r0 = reserve0;
        uint112 _r1 = reserve1;

        require(amount0Out < _r0 && amount1Out < _r1, "insufficient liquidity");

        if (amount0Out > 0) MockERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) MockERC20(token1).transfer(to, amount1Out);

        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        }

        uint256 bal0 = MockERC20(token0).balanceOf(address(this));
        uint256 bal1 = MockERC20(token1).balanceOf(address(this));

        uint256 amount0In = bal0 > uint256(_r0) - amount0Out ? bal0 - (uint256(_r0) - amount0Out) : 0;
        uint256 amount1In = bal1 > uint256(_r1) - amount1Out ? bal1 - (uint256(_r1) - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "insufficient input");

        // Uniswap V2 fee check: 0.3%
        uint256 bal0Adj = bal0 * 1000 - amount0In * 3;
        uint256 bal1Adj = bal1 * 1000 - amount1In * 3;
        require(bal0Adj * bal1Adj >= uint256(_r0) * uint256(_r1) * 1000 * 1000, "K");

        reserve0 = uint112(bal0);
        reserve1 = uint112(bal1);
    }
}

contract MockV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address a, address b, address p) external {
        getPair[a][b] = p;
        getPair[b][a] = p;
    }
}

contract MockV3Router {
    // rate = DAI per 1 WETH (unitless, both 18 decimals assumed)
    uint256 public rate; // e.g. 100 means 1 WETH = 100 DAI
    bool public shouldRevert;
    uint256 public callCount;

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function setRate(uint256 r) external { rate = r; }
    function setRevert(bool v) external { shouldRevert = v; }

    function exactOutputSingle(ExactOutputSingleParams calldata p) external payable returns (uint256 amountIn) {
        require(!shouldRevert, "router called");
        callCount++;

        require(rate > 0, "rate=0");

        // ceil(amountOut / rate)
        amountIn = (p.amountOut + rate - 1) / rate;
        require(amountIn <= p.amountInMaximum, "too much in");

        // take WETH from caller
        MockERC20(p.tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // pay DAI to recipient (router must have DAI balance)
        MockERC20(p.tokenOut).transfer(p.recipient, p.amountOut);
    }
}

contract UniswapV2FlashloanOppositeRepayTest is Test {
    // must match SUT hardcoded mainnet addresses
    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant V3_ROUTER  = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    MockERC20 weth;
    MockERC20 dai;
    MockV2Pair pair;            // normal deployed (not etched)
    MockV2Factory factory;      // etched into V2_FACTORY
    MockV3Router router;        // etched into V3_ROUTER

    UniswapV2FlashloanOppositeRepay sut;

    function setUp() public {
        vm.label(WETH, "WETH");
        vm.label(DAI, "DAI");
        vm.label(V2_FACTORY, "V2_FACTORY");
        vm.label(V3_ROUTER, "V3_ROUTER");

        // 1) Put ERC20 code at hardcoded token addresses
        MockERC20 t = new MockERC20();
        vm.etch(WETH, address(t).code);
        vm.etch(DAI,  address(t).code);
        weth = MockERC20(WETH);
        dai  = MockERC20(DAI);

        // 2) Deploy pair using these token addresses (token0=DAI, token1=WETH)
        pair = new MockV2Pair(DAI, WETH);

        // 3) Etch factory at hardcoded address and set pair
        MockV2Factory f = new MockV2Factory();
        vm.etch(V2_FACTORY, address(f).code);
        factory = MockV2Factory(V2_FACTORY);
        factory.setPair(DAI, WETH, address(pair));

        // 4) Etch V3 router at hardcoded address and configure
        MockV3Router r = new MockV3Router();
        vm.etch(V3_ROUTER, address(r).code);
        router = MockV3Router(V3_ROUTER);
        router.setRate(100); // 1 WETH = 100 DAI (unitless ratio)

        // give router DAI liquidity so it can pay out
        dai.mint(address(router), 10_000_000 ether);

        // 5) Seed pair reserves
        dai.mint(address(pair), 1_000_000 ether);
        weth.mint(address(pair), 10_000 ether);
        pair.sync();

        // 6) Deploy SUT (constructor reads factory at fixed address)
        sut = new UniswapV2FlashloanOppositeRepay();
    }

    function _daiNeeded(uint256 r0, uint256 r1, uint256 amount1Out) internal pure returns (uint256) {
        // daiNeeded = (r0 * amountOut * 1000) / ((r1 - amountOut) * 997) + 1
        return (r0 * amount1Out * 1000) / ((r1 - amount1Out) * 997) + 1;
    }

    function test_Flashloan_OppositeRepay_UsesRouter_WhenDAIInsufficient() public {
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        uint256 borrowWeth = 1 ether;
        uint256 needDAI = _daiNeeded(uint256(r0), uint256(r1), borrowWeth);

        // give a small extra WETH so swap-to-DAI can cover fee rounding
        weth.mint(address(sut), 0.02 ether);

        uint256 sutWethBefore = weth.balanceOf(address(sut));

        sut.flashloan(borrowWeth);

        // router should be called
        assertEq(router.callCount(), 1);

        // pair should have received DAI
        assertEq(dai.balanceOf(address(pair)), uint256(r0) + needDAI);
        // pair sent out WETH and didn't receive back WETH (repay in DAI)
        assertEq(weth.balanceOf(address(pair)), uint256(r1) - borrowWeth);

        // SUT spent some WETH to buy DAI; leftover WETH should be:
        // borrowed(1) + extra(0.02) - spent(ceil(needDAI/100))
        uint256 expectedSpent = (needDAI + 100 - 1) / 100;
        uint256 sutWethAfter = weth.balanceOf(address(sut));
        assertEq(sutWethAfter, sutWethBefore + borrowWeth - expectedSpent);

        // SUT should end with ~0 DAI (exactOutput then transferred to pair)
        assertEq(dai.balanceOf(address(sut)), 0);
    }

    function test_Flashloan_OppositeRepay_SkipsRouter_WhenDAIPrefunded() public {
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        uint256 borrowWeth = 1 ether;
        uint256 needDAI = _daiNeeded(uint256(r0), uint256(r1), borrowWeth);

        // pre-fund DAI so router is unnecessary
        dai.mint(address(sut), needDAI);

        // make router revert if called (to prove it's skipped)
        router.setRevert(true);

        sut.flashloan(borrowWeth);

        assertEq(router.callCount(), 0);

        assertEq(dai.balanceOf(address(pair)), uint256(r0) + needDAI);
        assertEq(weth.balanceOf(address(pair)), uint256(r1) - borrowWeth);

        // sut should have spent no WETH (only borrowed WETH stays as "profit" here)
        assertEq(weth.balanceOf(address(sut)), borrowWeth);
    }
}
