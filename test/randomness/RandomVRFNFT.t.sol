// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {RandomVRFNFT} from "src/randomness/RandomVRFNFT.sol";

contract RandomVRFNFTTest is Test {
    address constant VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    RandomVRFNFT nft;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    // requestRandomWords((bytes32,uint256,uint16,uint32,uint32,bytes))
    bytes4 constant REQ_SELECTOR =
        bytes4(keccak256("requestRandomWords((bytes32,uint256,uint16,uint32,uint32,bytes))"));

    function setUp() public {
        nft = new RandomVRFNFT(1);
    }

    function test_vrf_request_then_fulfill_mints() public {
        uint256 requestId = 777;

        // 让 coordinator 的 requestRandomWords 返回固定 requestId（前缀匹配更稳）
        vm.mockCall(
            VRF_COORDINATOR,
            abi.encodePacked(REQ_SELECTOR),
            abi.encode(requestId)
        );

        vm.prank(alice);
        uint256 rid = nft.mintRandomVRF();

        assertEq(rid, requestId);
        assertEq(nft.lastRequestId(), requestId);
        assertEq(nft.requestToSender(requestId), alice);

        uint256[] memory words = new uint256[](1);
        words[0] = 123456;

        vm.prank(VRF_COORDINATOR);
        nft.rawFulfillRandomWords(requestId, words);

        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.lastRandomWord(), 123456);
        assertEq(nft.requestToSender(requestId), address(0));
    }

    function test_only_coordinator_can_fulfill() public {
        uint256 requestId = 1;

       uint256[] memory words = new uint256[](1);
        words[0] = 1;


        vm.expectRevert();
        vm.prank(bob);
        nft.rawFulfillRandomWords(requestId, words);
    }

    function test_unknown_requestId_reverts() public {
        uint256 requestId = 999;

        uint256[] memory words = new uint256[](1);
        words[0] = 42;


        vm.expectRevert(bytes("unknown requestId"));
        vm.prank(VRF_COORDINATOR);
        nft.rawFulfillRandomWords(requestId, words);
    }
}
