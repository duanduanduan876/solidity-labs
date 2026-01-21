// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {MyERC721, ERC721ReceiverMock, IERC721Receiver} from "../../src/ERC721/MyERC721.sol";

contract MyERC721Test is Test {
    MyERC721 nft;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    string baseURI = "ipfs://bafybeiffog5zefg3egkngybakredxcjrbineiyqal6zewo3sa2ntlaussq/";

    function setUp() public {
        nft = new MyERC721("MyNFT", "MNFT", baseURI);
    }

    function testMintAndTokenURI() public {
        nft.mint(alice, 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.tokenURI(1), string.concat(baseURI, "1"));
    }

    function testTransferFromRejectsNonApproved() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(bytes("ERC721: not owner nor approved"));
        nft.transferFrom(alice, bob, 1);
    }

    function testApproveThenTransferFrom() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.getApproved(1), address(0));
    }

    function testSetApprovalForAllThenTransferFrom() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.prank(bob);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function testSafeTransferToEOA() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function testSafeTransferToReceiverOK() public {
        nft.mint(alice, 1);

        ERC721ReceiverMock recv = new ERC721ReceiverMock(IERC721Receiver.onERC721Received.selector, false);

        vm.expectEmit(true, true, true, true);
        emit ERC721ReceiverMock.Received(alice, alice, 1, "");

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(recv), 1, "");

        assertEq(nft.ownerOf(1), address(recv));
    }

    function testSafeTransferToReceiverBadRetvalReverts() public {
        nft.mint(alice, 1);

        ERC721ReceiverMock recv = new ERC721ReceiverMock(bytes4(0xdeadbeef), false);

        vm.prank(alice);
        vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver"));
        nft.safeTransferFrom(alice, address(recv), 1, "");
    }

    function testSafeTransferToReceiverReverts() public {
        nft.mint(alice, 1);

        ERC721ReceiverMock recv = new ERC721ReceiverMock(IERC721Receiver.onERC721Received.selector, true);

        vm.prank(alice);
        vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver"));
        nft.safeTransferFrom(alice, address(recv), 1, "");
    }
}
