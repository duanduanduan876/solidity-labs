// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {InterviewPermitToken} from "../../src/tokens/InterviewPermitToken.sol";

contract InterviewPermitTokenTest is Test {
    InterviewPermitToken token;

    uint256 buyerPk;
    address buyer;
    address spender;
    address relayer;

    bytes32 constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function setUp() public {
        token = new InterviewPermitToken("InterviewPermitToken", "IPT", 0);
        buyerPk = 0xA11CE;
        buyer = vm.addr(buyerPk);
        spender = address(0xBEEF);
        relayer = address(0xCAFE);

        token.mint(buyer, 1_000e18);
    }

    function _signPermit(
        uint256 pk,
        address owner,
        address _spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, _spender, value, nonce, deadline)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        (v, r, s) = vm.sign(pk, digest);
    }

    function testPermitSetsAllowanceAndIncrementsNonce() public {
        uint256 value = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(buyer);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(buyerPk, buyer, spender, value, nonce, deadline);

        vm.prank(relayer);
        token.permit(buyer, spender, value, deadline, v, r, s);

        assertEq(token.allowance(buyer, spender), value);
        assertEq(token.nonces(buyer), nonce + 1);
    }
}
