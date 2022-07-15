// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, network, run, upgrades } = require("hardhat");
const { NomicLabsHardhatPluginError } = require("hardhat/plugins");

const addresses = {
  mainnet: {
    factory: "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10",
    avax: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
    usdt: "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",
  },
  testnet: {
    factory: "0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10",
    avax: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
    usdt: "0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7",
  }
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
    let ERC20Price;
    if (network.name === "testnet") {
      ERC20Price = await ethers.getContractFactory("MockERC20Price");
    } else {
      ERC20Price = await ethers.getContractFactory("ERC20Price");
    }
    const erc20Price = await ERC20Price.deploy();
    await erc20Price.deployed();

    if (network.name === "mainnet") {
      await erc20Price.initialze(
        addresses[network.name].factory,
        addresses[network.name].avax,
        addresses[network.name].usdt
      );
    }
    
    console.log("Deployed ERC20Price Address: " + erc20Price.address);

    console.log("-------Verifying-----------");
    try {
      // verify
      await run("verify:verify", {
        address: erc20Price.address
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
