// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { CrossChainToken } from "src/bridge/CrossChainToken.sol";

contract CrossChainTokenTest is Test {
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function test_Deploy_WithInitSupply_MintsToOwner() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 1_000 ether);

        assertEq(t.owner(), owner);
        assertEq(t.totalSupply(), 1_000 ether);
        assertEq(t.balanceOf(owner), 1_000 ether);
    }

    function test_Deploy_WithZeroInitSupply_NoPreMint() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 0);

        assertEq(t.owner(), owner);
        assertEq(t.totalSupply(), 0);
        assertEq(t.balanceOf(owner), 0);
    }

    function test_Bridge_BurnsAndEmitsEvent() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 1_000 ether);

        // owner -> alice 100
        vm.prank(owner);
        t.transfer(alice, 100 ether);

        uint256 supplyBefore = t.totalSupply();
        uint256 aliceBefore  = t.balanceOf(alice);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit CrossChainToken.Bridge(alice, 40 ether);
        t.bridge(40 ether);

        assertEq(t.balanceOf(alice), aliceBefore - 40 ether);
        assertEq(t.totalSupply(), supplyBefore - 40 ether);
    }

    function test_Bridge_RevertIfInsufficientBalance() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 0);

        vm.prank(alice);
        vm.expectRevert(); // OZ 版本不同 revert 数据不同，这里做稳定匹配
        t.bridge(1 ether);
    }

    function test_Mint_OnlyOwner() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 0);

        vm.prank(alice);
        vm.expectRevert();
        t.mint(bob, 1 ether);
    }

    function test_Mint_OwnerMintsAndEmitsEvent() public {
        vm.prank(owner);
        CrossChainToken t = new CrossChainToken("X", "X", 0);

        uint256 supplyBefore = t.totalSupply();
        uint256 bobBefore = t.balanceOf(bob);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit CrossChainToken.Mint(bob, 123 ether);
        t.mint(bob, 123 ether);

        assertEq(t.balanceOf(bob), bobBefore + 123 ether);
        assertEq(t.totalSupply(), supplyBefore + 123 ether);
    }
}
