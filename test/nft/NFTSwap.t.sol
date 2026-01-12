// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {NFTSwap} from "src/nft/NFTSwap.sol";

contract MockERC721 {
    string public name;
    string public symbol;

    mapping(uint256 => address) internal _ownerOf;
    mapping(uint256 => address) internal _getApproved;

    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
    }

    function mint(address to, uint256 tokenId) external {
        require(_ownerOf[tokenId] == address(0), "already minted");
        _ownerOf[tokenId] = to;
    }

    function ownerOf(uint256 tokenId) external view returns (address owner) {
        owner = _ownerOf[tokenId];
        require(owner != address(0), "not minted");
    }

    function getApproved(uint256 tokenId) external view returns (address operator) {
        operator = _getApproved[tokenId];
    }

    function approve(address to, uint256 tokenId) external {
        require(_ownerOf[tokenId] == msg.sender, "not owner");
        _getApproved[tokenId] = to;
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_ownerOf[tokenId] == from, "wrong from");
        require(
            msg.sender == from || msg.sender == _getApproved[tokenId],
            "not approved"
        );

        _ownerOf[tokenId] = to;
        _getApproved[tokenId] = address(0);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);

        if (to.code.length > 0) {
            bytes4 ret = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                data
            );
            require(ret == IERC721Receiver.onERC721Received.selector, "unsafe receiver");
        }
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

contract GasHogSeller {
    NFTSwap public swap;
    MockERC721 public nft;
    uint256 public tokenId;
    uint256 public x;

    constructor(NFTSwap _swap, MockERC721 _nft, uint256 _tokenId) {
        swap = _swap;
        nft = _nft;
        tokenId = _tokenId;
    }

    function list(uint256 price) external {
        nft.approve(address(swap), tokenId);
        swap.list(address(nft), tokenId, price);
    }

    receive() external payable {
        // SSTORE > 2300 gas，会让 transfer 失败（用于暴露 NFTSwap 使用 transfer 的限制）
        x = 1;
    }
}

contract NFTSwapTest is Test {
    NFTSwap swap;
    MockERC721 nft;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    uint256 tokenId = 1;
    uint256 price = 1 ether;

    // 复制 NFTSwap 的事件签名（便于 expectEmit）
    event List(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Revoke(address indexed seller, address indexed nftAddr, uint256 indexed tokenId);
    event Update(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 newPrice);

    function setUp() public {
        vm.txGasPrice(0);

        swap = new NFTSwap();
        nft = new MockERC721("MockNFT", "MNFT");

        nft.mint(alice, tokenId);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _listAsAlice(uint256 p) internal {
        vm.startPrank(alice);
        nft.approve(address(swap), tokenId);

        vm.expectEmit(true, true, true, true);
        emit List(alice, address(nft), tokenId, p);

        swap.list(address(nft), tokenId, p);
        vm.stopPrank();

        // listed: NFT 在 swap，订单存在
        assertEq(nft.ownerOf(tokenId), address(swap));
        (address owner, uint256 gotPrice) = swap.nftList(address(nft), tokenId);
        assertEq(owner, alice);
        assertEq(gotPrice, p);
    }

    function test_List_Success() public {
        _listAsAlice(price);
    }

    function test_List_RevertIfNotApproved() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Need Approval"));
        swap.list(address(nft), tokenId, price);
    }

    function test_List_RevertIfPriceZero() public {
        vm.startPrank(alice);
        nft.approve(address(swap), tokenId);
        vm.expectRevert(bytes("Price must be greater than 0"));
        swap.list(address(nft), tokenId, 0);
        vm.stopPrank();
    }

    function test_Revoke_Success() public {
    _listAsAlice(price);

    vm.startPrank(alice);

    vm.expectEmit(true, true, true, true);
    emit Revoke(alice, address(nft), tokenId);

    swap.revoke(address(nft), tokenId);

    vm.stopPrank();

    assertEq(nft.ownerOf(tokenId), alice);
    (address owner, uint256 gotPrice) = swap.nftList(address(nft), tokenId);
    assertEq(owner, address(0));
    assertEq(gotPrice, 0);
}

    function test_Revoke_RevertIfNotOwner() public {
        _listAsAlice(price);

        vm.prank(bob);
        vm.expectRevert(bytes("Not owner"));
        swap.revoke(address(nft), tokenId);
    }

    function test_Update_Success() public {
    _listAsAlice(price);

    vm.startPrank(alice);

    vm.expectEmit(true, true, true, true);
    emit Update(alice, address(nft), tokenId, 2 ether);

    swap.update(address(nft), tokenId, 2 ether);

    vm.stopPrank();

    (address owner, uint256 gotPrice) = swap.nftList(address(nft), tokenId);
    assertEq(owner, alice);
    assertEq(gotPrice, 2 ether);
}
    function test_Update_RevertIfNotOwner() public {
        _listAsAlice(price);

        vm.prank(bob);
        vm.expectRevert(bytes("Not owner"));
        swap.update(address(nft), tokenId, 2 ether);
    }

    function test_Update_RevertIfPriceZero() public {
        _listAsAlice(price);

        vm.prank(alice);
        vm.expectRevert(bytes("Price must be greater than 0"));
        swap.update(address(nft), tokenId, 0);
    }

    function test_Purchase_Success_ExactPay() public {
    _listAsAlice(price);

    uint256 aliceBefore = alice.balance;
    uint256 bobBefore = bob.balance;

    vm.startPrank(bob);

    vm.expectEmit(true, true, true, true);
    emit Purchase(bob, address(nft), tokenId, price);

    swap.purchase{value: price}(address(nft), tokenId);

    vm.stopPrank();

    assertEq(nft.ownerOf(tokenId), bob);
    assertEq(alice.balance, aliceBefore + price);
    assertEq(bob.balance, bobBefore - price);

    (address owner, uint256 gotPrice) = swap.nftList(address(nft), tokenId);
    assertEq(owner, address(0));
    assertEq(gotPrice, 0);
}


    function test_Purchase_RefundsExtraEth() public {
        _listAsAlice(price);

        uint256 extra = 0.4 ether;

        uint256 aliceBefore = alice.balance;
        uint256 bobBefore = bob.balance;

        vm.prank(bob);
        swap.purchase{value: price + extra}(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(alice.balance, aliceBefore + price);
        // 由于多余 ETH 被退回，净支出应等于 price
        assertEq(bob.balance, bobBefore - price);
    }

    function test_Purchase_RevertIfNotForSale() public {
        vm.prank(bob);
        vm.expectRevert(bytes("NFT not for sale"));
        swap.purchase{value: 1 ether}(address(nft), tokenId);
    }

    function test_Purchase_RevertIfInsufficientPayment() public {
        _listAsAlice(price);

        vm.prank(bob);
        vm.expectRevert(bytes("Insufficient payment"));
        swap.purchase{value: price - 1}(address(nft), tokenId);
    }

    function test_Purchase_RevertIfSellerIsGasHogContract_transferLimit() public {
        uint256 t = 2;
        GasHogSeller seller = new GasHogSeller(swap, nft, t);
        nft.mint(address(seller), t);

        // seller 合约自己挂单
        seller.list(1 ether);

        vm.prank(bob);
        vm.expectRevert(); // transfer 给 seller 会失败（2300 gas 不够）
        swap.purchase{value: 1 ether}(address(nft), t);

        // revert 后状态应保持：NFT 仍在 swap，订单仍在
        assertEq(nft.ownerOf(t), address(swap));
        (address owner, uint256 gotPrice) = swap.nftList(address(nft), t);
        assertEq(owner, address(seller));
        assertEq(gotPrice, 1 ether);
    }
}
