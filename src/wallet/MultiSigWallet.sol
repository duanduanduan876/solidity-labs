// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    // 状态变量
    address[] public owners;                  // 多签持有人数组
    mapping(address => bool) public isOwner;  // 地址是否为多签持有人
    uint256 public ownerCount;                // 多签持有人数量
    uint256 public threshold;                 // 执行交易所需的最少签名数
    uint256 public nonce;                     // 防止重放攻击的随机数
    uint256 public chainId;                   // 链ID
    
    // 事件
    event ExecutionSuccess(bytes32 indexed txHash);
    event ExecutionFailure(bytes32 indexed txHash);
    event Deposit(address indexed sender, uint256 amount);
    
    // 构造函数，初始化owners和threshold
    constructor(address[] memory _owners, uint256 _threshold) {
        chainId = block.chainid;
        _setupOwners(_owners, _threshold);
    }
    
    /// @dev 初始化owners, isOwner, ownerCount,threshold 
    function _setupOwners(address[] memory _owners, uint256 _threshold) internal {
        require(threshold == 0, "WTF5000");
        require(_threshold <= _owners.length, "WTF5001");
        require(_threshold >= 1, "WTF5002");

        for (uint256 i = 0; i < _owners.length; i++) {
            //从数组中取出第i个地址赋值给owner
            address owner = _owners[i];
            require(owner != address(0), "WTF5003");
            //检查地址不是合约自身地址
            require(owner != address(this), "WTF5003");
            //检查该地址在当前的isowner映射中未被标记为true
            require(!isOwner[owner], "WTF5003");
            
            owners.push(owner);
            isOwner[owner] = true;
        }
        ownerCount = _owners.length;
        threshold = _threshold;
    }
    
    /// @dev 执行交易的核心函数
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) public payable virtual returns (bool success) {
        // 编码交易数据，计算哈希
        bytes32 txHash = encodeTransactionData(to, value, data, nonce, chainId);
        nonce++;  // 增加nonce防止重放攻击
        
        // 检查签名有效性
        checkSignatures(txHash, signatures);
        
        // 执行交易
        (success, ) = to.call{value: value}(data);
        
        // 处理执行结果
        if (success) {
            emit ExecutionSuccess(txHash);
        } else {
            emit ExecutionFailure(txHash);
            revert("WTF5004");
        }
    }
    
    /// @dev 检查签名有效性
    function checkSignatures(
        bytes32 dataHash,
        bytes memory signatures
    ) public view {
        require(threshold > 0, "WTF5005");
        require(signatures.length >= threshold * 65, "WTF5006");
        
        address lastOwner = address(0); 
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        
        for (uint256 i = 0; i < threshold; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            
            // 计算带前缀的哈希（EIP-191标准）
            bytes32 ethSignedHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)
            );
            
            // 恢复签名者地址
            currentOwner = ecrecover(ethSignedHash, v, r, s);
            
            // 验证签名者
            require(currentOwner > lastOwner, "WTF5007");
            require(isOwner[currentOwner], "WTF5007");
            lastOwner = currentOwner;
        }
    }
    
    /// @dev 从打包签名中分离单个签名
    function signatureSplit(bytes memory signatures, uint256 pos)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }
    
    /// @dev 编码交易数据
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce,
        uint256 chainid
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                to,
                value,
                keccak256(data),
                _nonce,
                chainid
            )
        );
    }
    
    // 接收以太币的fallback函数
    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }
    
    /// @dev 获取所有多签持有人地址
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}