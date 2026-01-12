// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// VRF v2.5
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract RandomVRFNFT is ERC721, VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                              NFT 参数
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply = 100;
    uint256[100] public ids;
    uint256 public mintCount;

    /*//////////////////////////////////////////////////////////////
                          VRF v2.5 (Sepolia L1)
    //////////////////////////////////////////////////////////////*/
    address constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B; // v2.5
    bytes32 constant KEY_HASH        = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    uint256 public immutable subId;        // v2.5: uint256
    uint32  public callbackGasLimit   = 100_000;
    uint16  public requestConfirmations = 3;  // 测试可调 1
    uint32  public numWords           = 1;

    mapping(uint256 => address) public requestToSender;
    uint256 public lastRequestId;
    uint256 public lastRandomWord;

    event RequestSent(uint256 indexed requestId, address indexed requester);
    event RandomFulfilled(uint256 indexed requestId, address indexed to, uint256 word, uint256 tokenId);

    constructor(uint256 _subId)
        ERC721("WTF Random", "WTF")
        VRFConsumerBaseV2Plus(VRF_COORDINATOR)  // 内部已使用 ConfirmedOwner，部署者为 owner
    {
        require(_subId != 0, "subId required");
        subId = _subId;
    }

    /* ====================== 链上伪随机（演示用） ====================== */
    function getRandomOnchain() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1), msg.sender, block.timestamp
        )));
    }

    function mintRandomOnchain() external {
        uint256 tokenId = _pickRandomUniqueId(getRandomOnchain());
        _safeMint(msg.sender, tokenId);
    }

    /* ====================== VRF 请求 & 回调 ====================== */
    function mintRandomVRF() external returns (uint256 requestId) {
        require(mintCount < totalSupply, "mint closed");

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: KEY_HASH,
            subId: subId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            // 用 LINK 支付；若想用原生 ETH，把 false 改成 true 并给订阅充 native
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({ nativePayment: false })
            )
        });

        requestId = s_vrfCoordinator.requestRandomWords(req);
        requestToSender[requestId] = msg.sender;
        lastRequestId = requestId;
        emit RequestSent(requestId, msg.sender);
    }

    // v2.5 回调参数使用 calldata
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address to = requestToSender[requestId];
        require(to != address(0), "unknown requestId");

        uint256 word = randomWords[0];
        uint256 tokenId = _pickRandomUniqueId(word);
        _safeMint(to, tokenId);

        lastRandomWord = word;
        delete requestToSender[requestId];

        emit RandomFulfilled(requestId, to, word, tokenId);
    }

    /* ====================== 自检辅助 ====================== */
    function isConsumer() external view returns (bool ok) {
        (, , , , address[] memory consumers) = s_vrfCoordinator.getSubscription(subId);
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == address(this)) return true;
        }
        return false;
    }

    function subInfo() external view returns (
        uint96 linkBalance,
        uint96 nativeBalance,
        uint64 reqCount,
        address owner,
        address[] memory consumers
    ) {
        return s_vrfCoordinator.getSubscription(subId);
    }

    function pendingRequest() external view returns (bool) {
        return s_vrfCoordinator.pendingRequestExists(subId);
    }

    /* ====================== 仅 owner 可调（使用 ConfirmedOwner 的 onlyOwner） ====================== */
    function setCallbackGasLimit(uint32 gasLimit) external onlyOwner { callbackGasLimit = gasLimit; }
    function setConfirmations(uint16 conf)     external onlyOwner { requestConfirmations = conf; }
    function setNumWords(uint32 n)             external onlyOwner { require(n > 0 && n <= 10, "bad n"); numWords = n; }

    /* ====================== 随机 tokenId 分配算法 ====================== */
    function _pickRandomUniqueId(uint256 random) private returns (uint256 tokenId) {
        uint256 len = totalSupply - mintCount++;
        require(len > 0, "mint closed");

        uint256 idx = random % len;
        tokenId      = (ids[idx] != 0) ? ids[idx] : idx;
        ids[idx]     = (ids[len - 1] == 0) ? (len - 1) : ids[len - 1];
        ids[len - 1] = 0;
    }
}
