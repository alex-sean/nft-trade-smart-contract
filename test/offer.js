const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange Offering", async () => {
  let exchange;
  let nft;
  let erc20;
  let owner, address1, address2;
  beforeEach(async () => {
    [owner, address1, address2] = await ethers.getSigners();
    const Exchange = await ethers.getContractFactory("Exchange");
    exchange = await Exchange.deploy();
    await exchange.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy("Test", "TEST", exchange.address, "");
    await nft.deployed();
    await nft.mintAll(100);

    const ERC20 = await ethers.getContractFactory("TestERC20");
    erc20 = await ERC20.deploy(100000);
    await erc20.deployed();

    await erc20.transfer(address1.address, 10000);
  })

  it("Offering to none token owner should be fail", async () => {
    await expect(exchange.connect(address1).offer(address2.address, nft.address, 1, erc20.address, 100))
      .to.be.revertedWith("Owner is not token owner.");
  });

  it("Offering without approval should be failed", async () => {
    await expect(exchange.connect(address1).offer(owner.address, nft.address, 1, erc20.address, 100))
      .to.be.revertedWith("Offer price is not approved.");
  });

  describe("Offering", () => {
    beforeEach(async () => {
      await erc20.connect(address1).approve(exchange.address, 100);
      await exchange.connect(address1).offer(owner.address, nft.address, 1, erc20.address, 100);
    })

    it("Multiple offering should be failed.", async () => {
      await expect(exchange.connect(address1).offer(owner.address, nft.address, 1, erc20.address, 50))
        .to.be.revertedWith("Offer exists already.");
    })

    it("Cancelling none existing offer should be failed", async () => {
      await expect(exchange.connect(address1).cancelOffer(owner.address, nft.address, 2, erc20.address))
        .to.be.revertedWith("Not exising offer.");
    })

    it("Cancelling offer to none token owner should be failed", async () => {
      await expect(exchange.connect(address1).cancelOffer(address2.address, nft.address, 1, erc20.address))
        .to.be.revertedWith("Owner is not token owner.");
    })

    it("Accepting order by none token owner should be failed", async () => {
      await expect(exchange.connect(address2).acceptOffer(nft.address, 1, address1.address, erc20.address, 100))
        .to.be.revertedWith("Owner is not token owner.");
    })

    it("Accepting order when erc721 token is not approved, should be failed", async () => {
      await expect(exchange.acceptOffer(nft.address, 1, address1.address, erc20.address, 100))
        .to.be.revertedWith("NFT token is not approved.");
    })

    it("Accepting order when erc20 token is not approved, should be failed", async () => {
      await erc20.connect(address1).decreaseAllowance(exchange.address, 50);
      await expect(exchange.acceptOffer(nft.address, 1, address1.address, erc20.address, 100))
        .to.be.revertedWith("Offer price is not approved.");
    })

    it("Accepting not existing offer should be failed", async () => {
      await nft.approve(exchange.address, 2);
      await expect(exchange.acceptOffer(nft.address, 2, address1.address, erc20.address, 100))
        .to.be.revertedWith("Not exising offer.");
    })

    it("Accepting offer should be succeseed", async() => {
      await nft.approve(exchange.address, 1);
      await exchange.acceptOffer(nft.address, 1, address1.address, erc20.address, 100);

      expect(await erc20.balanceOf(exchange.address)).to.equal(3);
      expect(await nft.ownerOf(1)).to.equal(address1.address);
      expect(await erc20.balanceOf(owner.address)).to.equal(90097);
    })

    it("Withdrawing with none owner should be failed", async() => {
      await nft.approve(exchange.address, 1);
      await exchange.acceptOffer(nft.address, 1, address1.address, erc20.address, 100);

      await expect(exchange.connect(address1).withdraw(erc20.address, 1))
        .to.be.revertedWith("Ownable: caller is not the owner");
    })

    it("Withdraw should be successed", async() => {
      await nft.approve(exchange.address, 1);
      await exchange.acceptOffer(nft.address, 1, address1.address, erc20.address, 100);

      await exchange.withdraw(erc20.address, 1);

      expect(await erc20.balanceOf(exchange.address)).to.equal(2);
      expect(await erc20.balanceOf(owner.address)).to.equal(90098);
    })
  })
});
