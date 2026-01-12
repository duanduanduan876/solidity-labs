// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { SimpleSwap, COLAToken, USDToken, ERC20Lite } from "src/dex/SimpleSwap.sol";

contract SimpleSwapTest is Test {
    COLAToken cola;
    USDToken usd;
    SimpleSwap pool;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function setUp() public {
        cola = new COLAToken();
        usd  = new USDToken();
        pool = new SimpleSwap(ERC20Lite(address(cola)), ERC20Lite(address(usd)));

        // 给测试账户铸币（ERC20Lite 允许任何人 mint）
        cola.mint(alice, 10_000 ether);
        usd.mint(alice,  10_000 ether);

        cola.mint(bob, 10_000 ether);
        usd.mint(bob,  10_000 ether);

        // 预先 approve（便于测试）
        vm.startPrank(alice);
        cola.approve(address(pool), type(uint256).max);
        usd.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        cola.approve(address(pool), type(uint256).max);
        usd.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    // 测试里复刻同样的 sqrt（保证和合约一致）
    function _sqrt(uint y) internal pure returns (uint z) {
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

    function _seedLiquidity(address provider, uint amount0, uint amount1) internal returns (uint liq) {
        vm.startPrank(provider);
        liq = pool.addLiquidity(amount0, amount1);
        vm.stopPrank();
    }

    function _k() internal view returns (uint) {
        uint r0 = cola.balanceOf(address(pool));
        uint r1 = usd.balanceOf(address(pool));
        return r0 * r1;
    }

    // ========== addLiquidity ==========

    function test_AddLiquidity_FirstMint_SqrtDxDy() public {
        uint dx = 100 ether;
        uint dy = 400 ether;

        uint expected = _sqrt(dx * dy);

        vm.startPrank(alice);
        uint liq = pool.addLiquidity(dx, dy);
        vm.stopPrank();

        assertEq(liq, expected);
        assertEq(pool.balanceOf(alice), expected);
        assertEq(pool.totalSupply(), expected);

        assertEq(cola.balanceOf(address(pool)), dx);
        assertEq(usd.balanceOf(address(pool)), dy);

        // 快照也应更新
        assertEq(pool.reserve0(), dx);
        assertEq(pool.reserve1(), dy);
    }

    function test_AddLiquidity_RevertIfZeroAmounts() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("amounts zero"));
        pool.addLiquidity(0, 1 ether);

        vm.expectRevert(bytes("amounts zero"));
        pool.addLiquidity(1 ether, 0);
        vm.stopPrank();
    }

    function test_AddLiquidity_SubsequentMint_MinAndKeepsExtraInPool() public {
        // 初始 100/100 -> LP=100
        uint liq1 = _seedLiquidity(alice, 100 ether, 100 ether);
        assertEq(liq1, 100 ether);

        // Bob 非比例注入：100 COLA + 10 USD
        // totalSupply=100, reserve0=100, reserve1=100
        // liq0 = 100*100/100=100
        // liq1 = 10*100/100=10  => mint 10
        vm.startPrank(bob);
        uint liq2 = pool.addLiquidity(100 ether, 10 ether);
        vm.stopPrank();

        assertEq(liq2, 10 ether);
        assertEq(pool.balanceOf(bob), 10 ether);
        assertEq(pool.totalSupply(), 110 ether);

        // 池子里确实留下“多出来的不按比例部分”（教学简化）
        assertEq(cola.balanceOf(address(pool)), 200 ether);
        assertEq(usd.balanceOf(address(pool)), 110 ether);
    }

    // ========== removeLiquidity ==========

    function test_RemoveLiquidity_Success_ProRata() public {
        uint dx = 1000 ether;
        uint dy = 1000 ether;
        uint liq = _seedLiquidity(alice, dx, dy);

        // 移除一半 LP
        uint burn = liq / 2;

        uint bal0Before = cola.balanceOf(alice);
        uint bal1Before = usd.balanceOf(alice);

        vm.startPrank(alice);
        (uint out0, uint out1) = pool.removeLiquidity(burn);
        vm.stopPrank();

        // 由于初始是 1:1 且无手续费，burn 一半应返回一半储备
        assertEq(out0, dx / 2);
        assertEq(out1, dy / 2);

        assertEq(cola.balanceOf(alice), bal0Before + out0);
        assertEq(usd.balanceOf(alice),  bal1Before + out1);

        assertEq(pool.totalSupply(), liq - burn);
        assertEq(pool.balanceOf(alice), liq - burn);

        assertEq(cola.balanceOf(address(pool)), dx - out0);
        assertEq(usd.balanceOf(address(pool)),  dy - out1);
    }

    function test_RemoveLiquidity_RevertIfZeroLiq() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("zero liq"));
        pool.removeLiquidity(0);
        vm.stopPrank();
    }

    function test_RemoveLiquidity_RevertIfNotEnoughLP() public {
        _seedLiquidity(alice, 100 ether, 100 ether);

        vm.startPrank(bob);
        vm.expectRevert(bytes("not enough LP"));
        pool.removeLiquidity(1 ether);
        vm.stopPrank();
    }

    // ========== swap ==========

    function test_Swap_Token0In_Success_KNonDecreasing() public {
        _seedLiquidity(alice, 1000 ether, 1000 ether);

        uint kBefore = _k();

        uint amountIn = 100 ether;
        uint rIn  = cola.balanceOf(address(pool));
        uint rOut = usd.balanceOf(address(pool));
        uint expectedOut = pool.getAmountOut(amountIn, rIn, rOut);

        uint bobUsdBefore = usd.balanceOf(bob);
        uint bobColaBefore = cola.balanceOf(bob);

        vm.startPrank(bob);
        (uint amountOut, address tokenOut) = pool.swap(amountIn, address(cola), expectedOut - 1);
        vm.stopPrank();

        assertEq(tokenOut, address(usd));
        assertEq(amountOut, expectedOut);

        assertEq(cola.balanceOf(bob), bobColaBefore - amountIn);
        assertEq(usd.balanceOf(bob),  bobUsdBefore + amountOut);

        uint kAfter = _k();
        assertGe(kAfter, kBefore); // 取整导致 k 可能增大，但不应变小
    }

    function test_Swap_Token1In_Success_KNonDecreasing() public {
        _seedLiquidity(alice, 1000 ether, 2000 ether);

        uint kBefore = _k();

        uint amountIn = 50 ether;
        uint rIn  = usd.balanceOf(address(pool));
        uint rOut = cola.balanceOf(address(pool));
        uint expectedOut = pool.getAmountOut(amountIn, rIn, rOut);

        uint bobUsdBefore = usd.balanceOf(bob);
        uint bobColaBefore = cola.balanceOf(bob);

        vm.startPrank(bob);
        (uint amountOut, address tokenOut) = pool.swap(amountIn, address(usd), expectedOut - 1);
        vm.stopPrank();

        assertEq(tokenOut, address(cola));
        assertEq(amountOut, expectedOut);

        assertEq(usd.balanceOf(bob),  bobUsdBefore - amountIn);
        assertEq(cola.balanceOf(bob), bobColaBefore + amountOut);

        uint kAfter = _k();
        assertGe(kAfter, kBefore);
    }

    function test_Swap_Revert_InvalidToken() public {
        _seedLiquidity(alice, 100 ether, 100 ether);

        address fake = makeAddr("fakeToken");
        vm.startPrank(bob);
        vm.expectRevert(bytes("INVALID_TOKEN"));
        pool.swap(1 ether, fake, 0);
        vm.stopPrank();
    }

    function test_Swap_Revert_InsufficientInputAmount() public {
        _seedLiquidity(alice, 100 ether, 100 ether);

        vm.startPrank(bob);
        vm.expectRevert(bytes("INSUFFICIENT_INPUT_AMOUNT"));
        pool.swap(0, address(cola), 0);
        vm.stopPrank();
    }

    function test_Swap_Revert_SlippageNote_StrictGreaterThan() public {
        _seedLiquidity(alice, 1000 ether, 1000 ether);

        uint amountIn = 100 ether;
        uint rIn  = cola.balanceOf(address(pool));
        uint rOut = usd.balanceOf(address(pool));
        uint expectedOut = pool.getAmountOut(amountIn, rIn, rOut);

        // 注意：合约用的是 `amountOut > amountOutMin`（严格大于）
        // 所以 amountOutMin == expectedOut 会 revert
        vm.startPrank(bob);
        vm.expectRevert(bytes("INSUFFICIENT_OUTPUT_AMOUNT"));
        pool.swap(amountIn, address(cola), expectedOut);
        vm.stopPrank();
    }
}
