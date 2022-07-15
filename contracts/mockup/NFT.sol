//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interface/IExchange.sol";

contract NFT is ERC721, Ownable {
    address public exchange = address(0);
    string public metadata = "";

    constructor(string memory name_, string memory symbol_, address exchange_, string memory metadata_) ERC721(name_, symbol_) {
        exchange = exchange_;
        metadata = metadata_;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return metadata;
    }

    /**
     * @dev mint all tokens at one time
     * @param totalSupply token count
     */
    function mintAll(uint256 totalSupply) public onlyOwner {
        for (uint256 i = 1; i <= totalSupply; i++) {
            _mint(msg.sender, i);
        }

        IExchange(exchange).emitNFTMintEvent(totalSupply, msg.sender);
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (from == address(0)) return;

        if (to == address(0)) {
            IExchange(exchange).emitNFTBurnEvent(tokenId, from);
        } else {
            IExchange(exchange).emitTransferEvent(tokenId, from, to);
        }
    }
}