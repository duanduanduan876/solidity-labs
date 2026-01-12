// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract NFTSwap is IERC721Receiver {
    // 事件定义
    event List(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Purchase(address indexed buyer, address indexed nftAddr, uint256 indexed tokenId, uint256 price);
    event Revoke(address indexed seller, address indexed nftAddr, uint256 indexed tokenId);    
    event Update(address indexed seller, address indexed nftAddr, uint256 indexed tokenId, uint256 newPrice);
    
    // 订单结构体
    struct Order {
        address owner;
        uint256 price;
    }
    
    // NFT订单映射
    mapping(address => mapping(uint256 => Order)) public nftList;
    
    // 接收ETH的回退函数
    fallback() external payable {}
    receive() external payable {}
    
    // 实现ERC721接收接口 - 修正警告：注释未使用参数名
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    // 挂单功能
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public {
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.getApproved(_tokenId) == address(this), "Need Approval");
        require(_price > 0, "Price must be greater than 0");
        
        Order storage _order = nftList[_nftAddr][_tokenId];
        _order.owner = msg.sender;
        _order.price = _price;
        
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }
    
    // 撤单功能
    function revoke(address _nftAddr, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "Not owner");
        
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "NFT not in contract");
        
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId];
        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }
    
    // 更新价格
    function update(address _nftAddr, uint256 _tokenId, uint256 _newPrice) public {
        require(_newPrice > 0, "Price must be greater than 0");
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "Not owner");
        
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "NFT not in contract");
        
        _order.price = _newPrice;
        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }
    
    // 购买功能
    function purchase(address _nftAddr, uint256 _tokenId) public payable {
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.price > 0, "NFT not for sale");
        require(msg.value >= _order.price, "Insufficient payment");
        
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "NFT not available");
        
        // 转移NFT
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        // 转移ETH
        payable(_order.owner).transfer(_order.price);
        
        // 处理多余ETH
        if (msg.value > _order.price) {
            payable(msg.sender).transfer(msg.value - _order.price);
        }
        
        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);
        delete nftList[_nftAddr][_tokenId];
    }
}