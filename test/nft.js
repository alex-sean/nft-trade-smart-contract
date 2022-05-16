const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT", function () {
  let nft;
  let owner, address1, address2;
  beforeEach(async () => {
    [owner, address1, address2] = await ethers.getSigners();

    const NFT = await ethers.getContractFactory("TestERC721");
    nft = await NFT.deploy("Test", "TEST", "http://localhost/metadata/");
    await nft.deployed();
  })

  it("BaseURI should be matched with the constructor parameters", async () => {
    expect(await nft.baseURI()).to.equal("http://localhost/metadata/");
  });

  describe("NFT Token Detail", async () => {
    beforeEach(async () => {
      await nft.mintAll(100);
    })

    it("Balance of owner should be 100", async() => {
      expect(await nft.balanceOf(owner.address)).to.equal(100);
    });

    it("Checking token uri", async() => {
      expect(await nft.tokenURI(10)).to.equal("http://localhost/metadata/10");
    })
  })
});
