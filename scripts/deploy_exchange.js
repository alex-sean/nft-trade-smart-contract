// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, network, run, upgrades } = require("hardhat");
const { NomicLabsHardhatPluginError } = require("hardhat/plugins");

const erc20PriceAddress = {
  mainnet: '0x973240f97297148cC9a179d1845dE00A5610Ab58',
  testnet: '0x973240f97297148cC9a179d1845dE00A5610Ab58'
}

async function main() {
  const signers = await ethers.getSigners();
  let deployer;
  signers.forEach((a) => {
    if (a.address === process.env.ADDRESS) {
      deployer = a;
    }
  });
  if (!deployer) {
    throw new Error(`${process.env.ADDRESS} not found in signers!`);
  }

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Network:", network.name);

  if (network.name === "testnet" || network.name === "mainnet") {
    console.log(`-------Deploying on ${network.name}-----------`);
    const Exchange = await ethers.getContractFactory("Exchange");
    const exchange = await Exchange.deploy();
    await exchange.deployed();

    await exchange.setERC20Price(erc20PriceAddress[network.name]);
    
    console.log("Deployed Exchange Address: " + exchange.address);

    console.log("-------Verifying-----------");
    try {
      // verify
      await run("verify:verify", {
        address: exchange.address
      });

    } catch (error) {
      if (error instanceof NomicLabsHardhatPluginError) {
        console.log("Contract source code already verified");
      } else {
        console.error(error);
      }
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
