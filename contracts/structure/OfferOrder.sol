//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


struct OfferOrder {
    address owner;
    address collectionAddress;
    uint256 tokenId;

    address buyer;
    address erc20Address;
    uint256 offerPrice;
}