const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange Ordering", async () => {
  let exchange;
  let nft;
  let erc20;
  let erc20Price;
  let owner, address1, address2;
  beforeEach(async () => {
    [owner, address1, address2] = await ethers.getSigners();
    const Exchange = await ethers.getContractFactory("Exchange");
    exchange = await Exchange.deploy();
    await exchange.deployed();

    const NFT = await ethers.getContractFactory("TestERC721");
    nft = await NFT.deploy("Test", "TEST", "http://localhost/metadata/");
    await nft.deployed();
    await nft.mintAll(100);

    const ERC20 = await ethers.getContractFactory("TestERC20");
    erc20 = await ERC20.deploy(100000);
    await erc20.deployed();

    await erc20.transfer(address1.address, 10000);

    const ERC20Price = await ethers.getContractFactory("MockERC20Price");
    erc20Price = await ERC20Price.deploy();
    await erc20Price.deployed();

    await exchange.setERC20Price(erc20Price.address);
  })

  it("Listing by none owner should be failed", async () => {
    await expect(exchange.connect(address1).list(nft.address, 1, 100, true, [], 1, 0))
      .to.be.revertedWith("Owner is not token owner.");
  })

  it("Listing by none approved token should be failed", async () => {
    await expect(exchange.list(nft.address, 1, 100, true, [], 1, 0))
      .to.be.revertedWith("NFT token is not approved.");
  })

  it("Listing with price zero should be failed.", async() => {
    await nft.approve(exchange.address, 1);
    await expect(exchange.list(nft.address, 1, 0, true, [nft.address], 1, 0))
      .to.be.revertedWith("Price is not set.");
  })

  it("Cancelling order should be failed when token is not listed", async() => {
    await expect(exchange.cancelSell(nft.address, 1))
      .to.be.revertedWith("Toekn is not listed.");
  })

  it("Listing on auction market should be failed when stable coin is acceptable", async() => {
    await nft.approve(exchange.address, 1);
    await expect(exchange.list(nft.address, 1, 100, true, [nft.address], 2, Date.now() + 1000000000000))
      .to.be.revertedWith("Auction time should be greater than 0 or stable coin is not acceptable.");
  })

  it("Listing on auction market should be failed when auctionEndTime is zero", async() => {
    await nft.approve(exchange.address, 1);
    await expect(exchange.list(nft.address, 1, 100, false, [nft.address], 2, 0))
      .to.be.revertedWith("Auction time should be greater than 0 or stable coin is not acceptable.");
  })

  it("Bidding to not listed token should be failed", async() => {
    await expect(exchange.bid(owner.address, nft.address, 1, erc20.address, 1000))
      .to.be.revertedWith("Token is not listed.");
  })

  describe("Listed on the market in fixed price and stable coin is acceptable", async() => {
    beforeEach(async () => {
      await nft.approve(exchange.address, 1);
      await exchange.list(nft.address, 1, 100, true, [erc20.address], 1, 0);
    })

    it("Multiple listing should be failed", async() => {
      await expect(exchange.list(nft.address, 1, 10, true, [erc20.address], 1, 0))
        .to.be.revertedWith("Toekn is already listed.");
    })

    it("Unlisting not owned token should be failed.", async() => {
      await expect(exchange.connect(address1).cancelSell(nft.address, 1))
        .to.be.revertedWith("Owner is not token owner.");
    })

    it("Unlisting token should be success.", async() => {
      await exchange.cancelSell(nft.address, 1);
    })

    it("Buying with not enough stable coin should be failed.", async() => {
      await expect(exchange.buyWithStableCoin(owner.address, nft.address, 1, {value: "2"}))
        .to.be.revertedWith("Price is not in range.");
    })

    it("Buying with enough stable coin should be success.", async() => {
      await exchange.connect(address1).buyWithStableCoin(owner.address, nft.address, 1, {value: 100});

      expect(await ethers.provider.getBalance(exchange.address)).to.equal(3);
    })

    it("Buying with unlisted token should be failed", async() => {
      await expect(exchange.connect(address1).buy(owner.address, nft.address, 1, nft.address, 100))
        .to.be.revertedWith("Token is not acceptable.");
    })

    it("Buying with not enough token should be failed.", async () => {
      await erc20.connect(address1).approve(exchange.address, 1);
      await expect(exchange.connect(address1).buy(owner.address, nft.address, 1, erc20.address, 1))
        .to.be.revertedWith("Price is not in range.");
    })

    it("Buying with enough token should be successed", async() => {
      await erc20.connect(address1).approve(exchange.address, 100);
      await exchange.connect(address1).buy(owner.address, nft.address, 1, erc20.address, 100);

      expect(await erc20.balanceOf(exchange.address)).to.equal(3);
      expect(await erc20.balanceOf(address1.address)).to.equal(9900);
      expect(await erc20.balanceOf(owner.address)).to.equal(90097)
    })
  })

  describe("Listed on the market in fixed price and stable coin is not acceptable", async() => {
    beforeEach(async () => {
      await nft.approve(exchange.address, 1);
      await exchange.list(nft.address, 1, 100, false, [erc20.address], 1, 0);
    })

    it("Buying with stable coin should be failed.", async() => {
      await expect(exchange.buyWithStableCoin(owner.address, nft.address, 1, {value: "2"}))
        .to.be.revertedWith("Stable coin is not acceptable.");
    })

    it("Bidding to fixed price should be failed", async () => {
      await erc20.connect(address1).approve(exchange.address, 100);
      await expect(exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 100))
        .to.be.revertedWith("Not listed on auction market.");
    })

    it("Completing auction of the token on fixed price should be failed", async() => {
      await expect(exchange.exchange(nft.address, 1, address1.address, erc20.address))
        .to.be.revertedWith("NFT token is not listed on auction market.");
    })
  })

  describe("Listed on Auction Market", async() => {
    beforeEach(async () => {
      await nft.approve(exchange.address, 1);
      await exchange.list(nft.address, 1, 100, false, [erc20.address], 2, Date.now() + 3600000);
    })

    it("Bidding with not enough token amount should be failed", async() => {
      await erc20.connect(address1).approve(exchange.address, 1);
      await expect(exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 1))
        .to.be.revertedWith("Bid amount should be greater than minimum price");
    })

    it("Multiple bidding should be failed", async () => {
      await erc20.connect(address1).approve(exchange.address, 200);
      await exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 100);
      await expect(exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 100))
        .to.be.revertedWith("Existing bid order.");
    })

    it("Bidding should be successed", async() => {
      await erc20.connect(address1).approve(exchange.address, 100);
      await exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 100);
    })

    it("Cancelling bid to not listed token should be failed.", async () => {
      await expect(exchange.connect(address1).cancelBid(owner.address, nft.address, 1, erc20.address))
        .to.be.revertedWith("Not existing bid");
    })

    describe("Bid order exists", async() => {
      beforeEach(async () => {
        await erc20.connect(address1).approve(exchange.address, 100);
        await exchange.connect(address1).bid(owner.address, nft.address, 1, erc20.address, 100);
      })

      it("Cancelling bid not to listed token should be failed", async() => {
        await expect(exchange.connect(address1).cancelBid(owner.address, nft.address, 2, erc20.address))
          .to.be.revertedWith("Token is not listed.");
      })

      it("Cancelling bid should be successed", async() => {
        await exchange.connect(address1).cancelBid(owner.address, nft.address, 1, erc20.address);
      })

      it("Completing auction with none token owner should be failed", async() => {
        await expect(exchange.connect(address1).exchange(nft.address, 1, address1.address, erc20.address))
          .to.be.revertedWith("Owner is not token owner.");
      })

      it("Completing auction with incorrect bid should be failed", async() => {
        await expect(exchange.exchange(nft.address, 1, address2.address, erc20.address))
          .to.be.revertedWith("Not existing bid order.");
      })

      it("Completing auction should be successed", async() => {
        await exchange.exchange(nft.address, 1, address1.address, erc20.address);

        expect(await erc20.balanceOf(exchange.address)).to.equal(3);
        expect(await erc20.balanceOf(address1.address)).to.equal(9900);
        expect(await erc20.balanceOf(owner.address)).to.equal(90097)
      })
    })
  })
});
