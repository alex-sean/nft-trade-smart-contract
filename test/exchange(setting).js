const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Exchange Setting", async () => {
  let exchange;
  let owner, address1, address2;
  beforeEach(async () => {
    [owner, address1, address2] = await ethers.getSigners();
    const Exchange = await ethers.getContractFactory("Exchange");
    exchange = await Exchange.deploy();
    await exchange.deployed();
  })

  it("Checking initial service fee and slippage", async () => {
    expect(await exchange.serviceFee()).to.equal(300);
    expect(await exchange.slippage()).to.equal(100);
  });

  it ("Setting service fee with out none owner should failed", async () => {
    await expect(exchange.connect(address1).setServiceFee(200))
      .to.be.revertedWith("Ownable: caller is not the owner");
  })

  it ("Setting service fee with owner should success", async () => {
    await exchange.setServiceFee(100);

    expect(await exchange.serviceFee()).to.equal(100);
  })
});
