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
import "./interface/IERC20Price.sol";
import "hardhat/console.sol";

contract Exchange is Ownable {
    using SafeMath for uint256;

    // sellOrders mapping(owner => mapping (collection => mapping(tokenId => SellOrder)));
    mapping(address => mapping(address => mapping(uint256 => SellOrder))) private sellOrders; 
    // offers mapping(owner => mapping (collection => mapping(tokenId => Offer[])));
    mapping(address => mapping(address => mapping(uint256 => OfferOrder[]))) private offers;

    uint256 public serviceFee = 300;  // service fee in percent with decimal 2. e.g. 200(2%)

    IERC20Price public erc20Price;

    uint256 public slippage = 100;    // slippage in percent with decimal 2. e.g. 200(2%)

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

    /**
     * @dev event of accepting the order
     * @param owner token owner
     * @param collectionAddress ERC721 address
     * @param tokenId token id
     * @param buyer token buyer
     * @param erc20Address offering token address
     * @param offerAmount offering price
     */
    event AcceptOffer(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address,
        uint256 offerAmount
    );

    /**
     * @dev event of withdraw
     * @param erc20Address token address to withdraw
     * @param amount withdraw amount
     * @param to address to withdraw
     */
    event Withdraw(
        address erc20Address,
        uint256 amount,
        address to
    );
    
    /**
     * @dev event of listing
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param isStableCoin if owner wants to accept is stable coin, set true
     * @param erc20ContractAddresses accepctable erc20 contract addresses
     * @param orderType order type(with fixed price or auction)
     * @param auctionEndTime auction end time. if selling with fixed price, set 0
     */
    event List (
        address owner,
        address collectionAddress,
        uint256 tokenId,
        uint256 price,
        bool isStableCoin,
        address[] erc20ContractAddresses,
        OrderType orderType,
        uint256 auctionEndTime
    );

    /**
     * @dev event of unlisting the token
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     */
    event CancelSell(
        address owner,
        address collectionAddress,
        uint256 tokenId
    );

    /**
     * @dev event of buying nft token with stable coin
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     * @param buyer buyer
     * @param amount buy price
     */
    event BuyWithStableCoin(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        uint256 amount
    );

    /**
     * @dev buy nft token
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     * @param erc20Address erc20 token to buy
     * @param amount token amount
     */
    event Buy(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address,
        uint256 amount
    );

    /**
     * @dev event of bid to sell order
     * @param owner token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param erc20Address erc20 address
     * @param amount erc20 token amount
     */
    event Bid(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address,
        uint256 amount
    );

    /**
     * @dev cancel event of the bid 
     * @param owner token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param erc20Address erc20 address
     */
    event CancelBid(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address
    );

    /**
     * @dev event of completing the auction
     * @param owner owner of nft token
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     * @param buyer buyer address
     * @param erc20Address erc20 token address
     */
    event AuctionEnd(
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
     * @dev set erc20price contract
     * @param _erc20Price erc20price contract address
     */
    function setERC20Price(IERC20Price _erc20Price) external onlyOwner {
        erc20Price = _erc20Price;
    }

    /**
     * @dev set slippage
     * @param _slippage slippage value
     */
    function setSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;
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
        require(IERC20(erc20Address).allowance(msg.sender, address(this)) >= offerPrice, "Offer price is not approved.");
        require(IERC20(erc20Address).balanceOf(msg.sender) >= offerPrice, "Insufficient balance.");

        bool exist = false;
        for (uint256 i = 0; i < offers[owner][collectionAddress][tokenId].length; i++) {
             if (
                offers[owner][collectionAddress][tokenId][i].owner == owner &&
                offers[owner][collectionAddress][tokenId][i].collectionAddress == collectionAddress &&
                offers[owner][collectionAddress][tokenId][i].tokenId == tokenId &&
                offers[owner][collectionAddress][tokenId][i].buyer == msg.sender &&
                offers[owner][collectionAddress][tokenId][i].erc20Address == erc20Address
            ) {
                exist = true;
                break;
            }
        }

        require(!exist, "Offer exists already.");

        OfferOrder memory offerToAdd = OfferOrder(
            owner,
            collectionAddress,
            tokenId,
            msg.sender,
            erc20Address,
            offerPrice
        );

        offers[owner][collectionAddress][tokenId].push(offerToAdd);

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
            if (
                offers[owner][collectionAddress][tokenId][i].owner == owner &&
                offers[owner][collectionAddress][tokenId][i].collectionAddress == collectionAddress &&
                offers[owner][collectionAddress][tokenId][i].tokenId == tokenId &&
                offers[owner][collectionAddress][tokenId][i].buyer == msg.sender &&
                offers[owner][collectionAddress][tokenId][i].erc20Address == erc20Address
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

    /**
     * @dev accept offer
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param buyer buyer address
     * @param erc20Address offering token address
     * @param offerPrice offering price
     */
    function acceptOffer(
        address collectionAddress, 
        uint256 tokenId,
        address buyer,
        address erc20Address,
        uint256 offerPrice
    ) public {
        require(IERC721(collectionAddress).ownerOf(tokenId) == msg.sender, "Owner is not token owner.");
        require(IERC20(erc20Address).allowance(buyer, address(this)) >= offerPrice, "Offer price is not approved.");
        require(IERC721(collectionAddress).getApproved(tokenId) == address(this), "NFT token is not approved.");

        for (uint256 i = 0; i < offers[msg.sender][collectionAddress][tokenId].length; i++) {
            if (
                offers[msg.sender][collectionAddress][tokenId][i].owner == msg.sender &&
                offers[msg.sender][collectionAddress][tokenId][i].collectionAddress == collectionAddress &&
                offers[msg.sender][collectionAddress][tokenId][i].tokenId == tokenId &&
                offers[msg.sender][collectionAddress][tokenId][i].buyer == buyer &&
                offers[msg.sender][collectionAddress][tokenId][i].erc20Address == erc20Address
            ) {
                uint256 feeAmount = offerPrice.mul(serviceFee).div(100 * 100);
                uint256 amountToOwner = offerPrice.sub(feeAmount);

                IERC721(collectionAddress).safeTransferFrom(msg.sender, buyer, tokenId);
                IERC20(erc20Address).transferFrom(buyer, address(this), feeAmount);
                IERC20(erc20Address).transferFrom(buyer, msg.sender, amountToOwner);

                delete offers[msg.sender][collectionAddress][tokenId];

                emit AcceptOffer(msg.sender, collectionAddress, tokenId, buyer, erc20Address, offerPrice);
                return;
            }
        }

        require(false, "Not exising offer.");
    }

    /**
     * @dev withdraw the token
     * @param erc20Address withdraw token address
     * @param amount withdraw amount
     */
    function withdraw(
        address erc20Address,
        uint256 amount
    ) public onlyOwner {
        require(IERC20(erc20Address).balanceOf(address(this)) >= amount, "Insufficient balance");

        IERC20(erc20Address).transfer(msg.sender, amount);
        emit Withdraw(erc20Address, amount, msg.sender);
    }

    /**
     * @dev list the token on the market
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param isStableCoin if owner wants to accept is stable coin, set true
     * @param erc20ContractAddresses accepctable erc20 contract addresses
     * @param orderType order type(with fixed price or auction)
     * @param auctionEndTime auction end time. if selling with fixed price, set 0
     */
    function list(
        address collectionAddress,
        uint256 tokenId,
        uint256 price,
        bool isStableCoin,
        address[] memory erc20ContractAddresses,
        OrderType orderType,
        uint256 auctionEndTime
    ) external {
        require(IERC721(collectionAddress).ownerOf(tokenId) == msg.sender, "Owner is not token owner.");
        require(IERC721(collectionAddress).getApproved(tokenId) == address(this), "NFT token is not approved.");
        require(
            sellOrders[msg.sender][collectionAddress][tokenId].orderType == OrderType.NONE,
            "Toekn is already listed."
        );
        require(price > 0, "Price is not set.");
        require(
            orderType == OrderType.FIXED_PRICE || 
            (orderType == OrderType.AUCTION && auctionEndTime > 0 && isStableCoin == false),
            "Auction time should be greater than 0 or stable coin is not acceptable." 
        );
        
        sellOrders[msg.sender][collectionAddress][tokenId].seller = msg.sender;
        sellOrders[msg.sender][collectionAddress][tokenId].collectionAddress = collectionAddress;
        sellOrders[msg.sender][collectionAddress][tokenId].tokenId = tokenId;
        sellOrders[msg.sender][collectionAddress][tokenId].usdtPrice = price;
        sellOrders[msg.sender][collectionAddress][tokenId].isStableCoin = isStableCoin;
        sellOrders[msg.sender][collectionAddress][tokenId].erc20ContractAddresses = erc20ContractAddresses;
        sellOrders[msg.sender][collectionAddress][tokenId].orderType = orderType;
        sellOrders[msg.sender][collectionAddress][tokenId].selectedBidIndex = 0;
        sellOrders[msg.sender][collectionAddress][tokenId].status = OrderStatus.LISTING;
        sellOrders[msg.sender][collectionAddress][tokenId].auctionEndTime = auctionEndTime;

        emit List(
            msg.sender,
            collectionAddress,
            tokenId,
            price,
            isStableCoin,
            erc20ContractAddresses,
            orderType, 
            auctionEndTime
        );
    }

    /**
     * @dev unlist the token
     * @param collectionAddress nft collection address
     * @param tokenId token id
     */
    function cancelSell(
        address collectionAddress,
        uint256 tokenId
    ) external {
        require(IERC721(collectionAddress).ownerOf(tokenId) == msg.sender, "Owner is not token owner.");
        require(
            sellOrders[msg.sender][collectionAddress][tokenId].orderType == OrderType.FIXED_PRICE ||
            sellOrders[msg.sender][collectionAddress][tokenId].orderType == OrderType.AUCTION,
            "Toekn is not listed."
        );

        delete sellOrders[msg.sender][collectionAddress][tokenId];

        emit CancelSell(msg.sender, collectionAddress, tokenId);
    }

    /**
     * @dev buy nft token with stable coin
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     */
    function buyWithStableCoin(
        address owner,
        address collectionAddress,
        uint256 tokenId
    ) external payable {
        require(sellOrders[owner][collectionAddress][tokenId].seller == owner, "NFT token is not listed.");
        require(sellOrders[owner][collectionAddress][tokenId].isStableCoin, "Stable coin is not acceptable.");
        require(
            sellOrders[owner][collectionAddress][tokenId].orderType == OrderType.FIXED_PRICE,
            "Token is listed on auction market."
        );

        uint256 usdtAmount = erc20Price.getAVAXPrice().mul(msg.value).div(10 ** 18);
        require(
            sellOrders[owner][collectionAddress][tokenId].usdtPrice.mul(100 * 100 - slippage).div(100 * 100) <= usdtAmount,
            "Price is not in range."
        );

        uint256 feeAmount = msg.value.mul(serviceFee).div(100 * 100);
        
        IERC721(collectionAddress).safeTransferFrom(owner, msg.sender, tokenId);
        payable(msg.sender).transfer(msg.value.sub(feeAmount));

        emit BuyWithStableCoin(owner, collectionAddress, tokenId, msg.sender, msg.value);
    }

    /**
     * @dev buy nft token
     * @param owner nft token owner
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     * @param erc20Address erc20 token to buy
     * @param amount token amount
     */
    function buy(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address erc20Address,
        uint256 amount
    ) external payable {
        require(sellOrders[owner][collectionAddress][tokenId].seller == owner, "NFT token is not listed.");
        require(
            sellOrders[owner][collectionAddress][tokenId].orderType == OrderType.FIXED_PRICE,
            "Token is listed on auction market."
        );

        bool tokenAcceptable = false;
        for (uint256 i = 0; i < sellOrders[owner][collectionAddress][tokenId].erc20ContractAddresses.length; i++) {
            if (sellOrders[owner][collectionAddress][tokenId].erc20ContractAddresses[i] == erc20Address) {
                tokenAcceptable = true;
                break;
            }
        }

        require(tokenAcceptable, "Token is not acceptable.");

        uint256 usdtAmount = erc20Price.getTokenPrice(erc20Address).mul(amount).div(10 ** 18);
        require(
            sellOrders[owner][collectionAddress][tokenId].usdtPrice.mul(100 * 100 - slippage).div(100 * 100) <= usdtAmount,
            "Price is not in range."
        );

        uint256 feeAmount = amount.mul(serviceFee).div(100 * 100);
        
        IERC721(collectionAddress).safeTransferFrom(owner, msg.sender, tokenId);
        IERC20(erc20Address).transferFrom(msg.sender, owner, amount.sub(feeAmount));
        IERC20(erc20Address).transferFrom(msg.sender, address(this), feeAmount);

        emit Buy(owner, collectionAddress, tokenId, msg.sender, erc20Address, amount);
    }

    /**
     * @dev bid to sell order
     * @param owner token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param erc20Address erc20 address
     * @param amount erc20 token amount
     */
    function bid(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address erc20Address,
        uint256 amount
    ) external {
        require(sellOrders[owner][collectionAddress][tokenId].status == OrderStatus.LISTING, "Token is not listed.");
        require(sellOrders[owner][collectionAddress][tokenId].seller == owner, "NFT token is not listed.");
        require(IERC20(erc20Address).allowance(msg.sender, address(this)) >= amount, "Offer price is not approved.");
        require(IERC20(erc20Address).balanceOf(msg.sender) >= amount, "Insufficient balance.");
        require(
            sellOrders[owner][collectionAddress][tokenId].orderType == OrderType.AUCTION,
            "Not listed on auction market."
        );
        require(
            sellOrders[owner][collectionAddress][tokenId].auctionEndTime > block.timestamp,
            "Auction has been ended"
        );

        bool tokenAcceptable = false;
        for (uint256 i = 0; i < sellOrders[owner][collectionAddress][tokenId].erc20ContractAddresses.length; i++) {
            if (sellOrders[owner][collectionAddress][tokenId].erc20ContractAddresses[i] == erc20Address) {
                tokenAcceptable = true;
                break;
            }
        }

        require(tokenAcceptable, "Token is not acceptable.");

        for (uint256 i = 0; i < sellOrders[owner][collectionAddress][tokenId].bidOrders.length; i++) {
            if (
                sellOrders[owner][collectionAddress][tokenId].bidOrders[i].buyer == msg.sender &&
                sellOrders[owner][collectionAddress][tokenId].bidOrders[i].erc20ContractAddress == erc20Address
            ) {
                require(false, "Existing bid order.");
            }
        }

        uint256 usdtAmount = erc20Price.getTokenPrice(erc20Address).mul(amount).div(10 ** 18);
        require(
            sellOrders[owner][collectionAddress][tokenId].usdtPrice.mul(100 * 100 - slippage).div(100 * 100) <= usdtAmount,
            "Bid amount should be greater than minimum price"
        );

        sellOrders[owner][collectionAddress][tokenId].bidOrders.push(BidOrder(
            msg.sender,
            erc20Address,
            amount
        ));

        emit Bid(owner, collectionAddress, tokenId, msg.sender, erc20Address, amount);
    }

    /**
     * @dev cancel the bid 
     * @param owner token owner
     * @param collectionAddress nft collection address
     * @param tokenId token id
     * @param erc20Address erc20 address
     */
    function cancelBid(
        address owner,
        address collectionAddress,
        uint256 tokenId,
        address erc20Address
    ) external {
        require(sellOrders[owner][collectionAddress][tokenId].status == OrderStatus.LISTING, "Token is not listed.");
        require(sellOrders[owner][collectionAddress][tokenId].seller == owner, "NFT token is not listed.");
        require(
            sellOrders[owner][collectionAddress][tokenId].orderType == OrderType.AUCTION,
            "Not listed on auction market."
        );
        require(
            sellOrders[owner][collectionAddress][tokenId].auctionEndTime > block.timestamp,
            "Auction has been ended"
        );

        bool cancelable = false;
        for (uint256 i = 0; i < sellOrders[owner][collectionAddress][tokenId].bidOrders.length; i++) {
            if (
                sellOrders[owner][collectionAddress][tokenId].bidOrders[i].buyer == msg.sender &&
                sellOrders[owner][collectionAddress][tokenId].bidOrders[i].erc20ContractAddress == erc20Address
            ) {
                sellOrders[owner][collectionAddress][tokenId].bidOrders[i] = 
                    sellOrders[owner][collectionAddress][tokenId].bidOrders[
                        sellOrders[owner][collectionAddress][tokenId].bidOrders.length - 1
                    ];
                sellOrders[owner][collectionAddress][tokenId].bidOrders.pop();
                cancelable = true;
                break;
            }
        }

        require(cancelable, "Not existing bid.");

        emit CancelBid(owner, collectionAddress, tokenId, msg.sender, erc20Address);
    }

    /**
     * @dev complete the auction
     * @param collectionAddress nft collection address
     * @param tokenId nft token id
     * @param buyer buyer address
     * @param erc20Address erc20 token address
     */
    function exchange(
        address collectionAddress,
        uint256 tokenId,
        address buyer,
        address erc20Address
    ) external {
        require(IERC721(collectionAddress).ownerOf(tokenId) == msg.sender, "Owner is not token owner.");
        require(IERC721(collectionAddress).getApproved(tokenId) == address(this), "NFT token is not approved.");
        require(
            sellOrders[msg.sender][collectionAddress][tokenId].orderType == OrderType.AUCTION,
            "NFT token is not listed on auction market."
        );
        
        for (uint256 i = 0; i < sellOrders[msg.sender][collectionAddress][tokenId].bidOrders.length; i++) {
            if (
                sellOrders[msg.sender][collectionAddress][tokenId].bidOrders[i].buyer == buyer &&
                sellOrders[msg.sender][collectionAddress][tokenId].bidOrders[i].erc20ContractAddress == erc20Address
            ) {
                uint256 feeAmount = sellOrders[msg.sender][collectionAddress][tokenId].bidOrders[i].bidAmount.mul(serviceFee).div(100 * 100);
                uint256 amountToOwner = sellOrders[msg.sender][collectionAddress][tokenId].bidOrders[i].bidAmount.sub(feeAmount);

                IERC721(collectionAddress).safeTransferFrom(msg.sender, buyer, tokenId);
                IERC20(erc20Address).transferFrom(buyer, address(this), feeAmount);
                IERC20(erc20Address).transferFrom(buyer, msg.sender, amountToOwner);

                emit AuctionEnd(msg.sender, collectionAddress, tokenId, buyer, erc20Address);
                return;
            }
        }
        
        require(false, "Not existing bid order.");
    }
}
