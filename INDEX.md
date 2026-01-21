
## NFT / MyERC721 (ERC721 + Metadata + safeTransfer demo)

- Source: `src/nft/MyERC721.sol`
- Tests: `test/nft/MyERC721.t.sol`
- Run: `forge test --match-path test/nft/MyERC721.t.sol -vvv`
- What it proves: ERC721 approvals (approve / setApprovalForAll), transferFrom access control, safeTransfer receiver handshake (onERC721Received selector check), tokenURI baseURI composition for IPFS metadata.
