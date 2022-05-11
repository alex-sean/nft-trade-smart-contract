//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC721 is ERC721, Ownable {
    string private baseURI = "";

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        
    }

    /**
     * @dev set BaseURI
     * @param uri uri string 
     */
    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    /**
     * @dev return base uri
     * @return returns saved base uri
     */
    function _baseURI() internal view override returns(string memory) {
        return baseURI;
    }

    /**
     * @dev mint all tokens at one time
     * @param totalSupply token count
     */
    function mintAll(uint256 totalSupply) public onlyOwner {
        for (uint256 i = 1; i <= totalSupply; i++) {
            _mint(msg.sender, i);
        }
    }
}