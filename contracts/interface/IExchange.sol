// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IExchange {
  /**
    * @dev emit transfer event
    * @param tokenId nft token id
    * @param from from address
    * @param to to address
    */
  function emitTransferEvent(uint256 tokenId, address from, address to) external;

  /**
    * @dev emit mint event
    * @param supply supply
    * @param owner owner
    */
  function emitNFTMintEvent(uint256 supply, address owner) external;

  /**
    * @dev emit burn event
    * @param tokenId supply
    * @param owner owner
    */
  function emitNFTBurnEvent(uint256 tokenId, address owner) external;
}