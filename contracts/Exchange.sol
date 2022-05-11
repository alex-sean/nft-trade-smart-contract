//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./const/OrderStatus.sol";
import "./const/OrderType.sol";
import "./const/OfferStatus.sol";
import "./structure/SellOrder.sol";
import "./structure/BidOrder.sol";
import "./structure/OfferOrder.sol";

contract Exchange is Ownable {
    using SafeMath for uint256;

    // sellOrders mapping(owner => mapping (collection => mapping(tokenId => SellOrder)));
    mapping(address => mapping(address => mapping(uint256 => SellOrder))) private sellOrders; 
    // offers mapping(owner => mapping (collection => mapping(tokenId => Offer[])));
    mapping(address => mapping(address => mapping(uint256 => OfferOrder[]))) private offers;

    uint256 public serviceFee;  // service fee in percent with decimal 2. e.g. 200(2%)

    /**
     * @dev event of setting fee operation
     * @param fee service fee percentage
     */
    event SetServiceFee(uint256 indexed fee);

    /**
     * @dev event of offering
     * @param owner token owner
     * @param collectionAddress ERC721 address
     * @param tokenId token id
     * @param buyer token buyer
     * @param erc20Address offering token address
     * @param offerAmount offering price
     */
    event Offer(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address,
        uint256 offerAmount
    );

    /**
     * @dev cancel event of offering
     * @param owner token owner
     * @param collectionAddress ERC721 address
     * @param tokenId token id
     * @param buyer token buyer
     * @param erc20Address offering token address
     */
    event CancelOffer(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address
    );

    constructor() {
        
    }

    /**
     * @dev set service fee percentage
     * @param fee service fee percentage
     */
    function setServiceFee(uint256 fee) public onlyOwner {
        require(serviceFee < 100 * 100, "Service fee can't be over 100%.");

        serviceFee = fee;
        
        emit SetServiceFee(fee);
    }

    /**
     * @dev Offer to token
     * @param owner token owner address
     * @param collectionAddress ERC721 collection address
     * @param tokenId token Id
     * @param erc20Address offering token address
     * @param offerPrice offering price
     */
    function offer(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address erc20Address,
        uint256 offerPrice
    ) external {
        require(IERC721(collectionAddress).ownerOf(tokenId) == owner, "Owner is not token owner.");
        require(IERC20(erc20Address).allowance(msg.sender, address(this)) > offerPrice, "Offer price is not approved.");
        require(IERC20(erc20Address).balanceOf(msg.sender) >= offerPrice, "Insufficient balance.");

        bool exist = false;
        for (uint256 i = 0; i < offers[owner][collectionAddress][tokenId].length; i++) {
            OfferOrder memory offer = offers[owner][collectionAddress][tokenId][i];

             if (
                offer.owner == owner &&
                offer.collectionAddress == collectionAddress &&
                offer.tokenId == tokenId &&
                offer.buyer == msg.sender &&
                offer.erc20Address == erc20Address
            ) {
                exist = true;
                break;
            }
        }

        require(!exist, "Offer exists already.");

        OfferOrder memory offer = OfferOrder(
            owner,
            collectionAddress,
            tokenId,
            msg.sender,
            erc20Address,
            offerPrice
        );

        offers[owner][collectionAddress][tokenId].push(offer);

        emit Offer(owner, collectionAddress, tokenId, msg.sender, erc20Address, offerPrice);
    }

    /**
     * @dev Cancel the offer
     * @param owner token owner address
     * @param collectionAddress ERC721 collection address
     * @param tokenId token Id
     * @param erc20Address offering token address
     */
    function cancelOffer(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address erc20Address
    ) external {
        require(IERC721(collectionAddress).ownerOf(tokenId) == owner, "Owner is not token owner.");

        for (uint256 i = 0; i < offers[owner][collectionAddress][tokenId].length; i++) {
            OfferOrder memory offer = offers[owner][collectionAddress][tokenId][i];

            if (
                offer.owner == owner &&
                offer.collectionAddress == collectionAddress &&
                offer.tokenId == tokenId &&
                offer.buyer == msg.sender &&
                offer.erc20Address == erc20Address
            ) {
                for (uint256 j = i; j < offers[owner][collectionAddress][tokenId].length - 1; i++) {
                    offers[owner][collectionAddress][tokenId][j] = offers[owner][collectionAddress][tokenId][j + 1];
                }

                delete offers[owner][collectionAddress][tokenId][offers[owner][collectionAddress][tokenId].length - 1];
                offers[owner][collectionAddress][tokenId].pop();

                emit CancelOffer(owner, collectionAddress, tokenId, msg.sender, erc20Address);
                return;
            }
        }

        require(false, "Not exising offer.");
    }
}
