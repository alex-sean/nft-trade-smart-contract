const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT", function () {
  let nft, exchange;
  let owner, address1, address2;
  beforeEach(async () => {
    [owner, address1, address2] = await ethers.getSigners();

    const Exchange = await ethers.getContractFactory("Exchange");
    exchange = await Exchange.deploy();
    await exchange.deployed();

    const NFT = await ethers.getContractFactory("NFT");
    nft = await NFT.deploy("Test", "TEST", exchange.address, "abc");
    await nft.deployed();
  })

  describe("NFT Token Detail", async () => {
    beforeEach(async () => {
      await nft.mintAll(100);
    })

    it("Metadata should be abc", async() => {
      expect(await nft.metadata()).to.equal('abc');
    });

    it("Balance of owner should be 100", async() => {
      expect(await nft.balanceOf(owner.address)).to.equal(100);
    });

    it("Checking token uri", async() => {
      expect(await nft.tokenURI(10)).to.equal("abc");
    })
  })
});
