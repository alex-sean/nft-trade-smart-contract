// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, network, run, upgrades } = require("hardhat");
const { NomicLabsHardhatPluginError } = require("hardhat/plugins");

const exchangeAddress = {
  mainnet: '0x237DFa198DbF4e1A22C6f6b522CEd1Bfdd15238B',
  testnet: '0x237DFa198DbF4e1A22C6f6b522CEd1Bfdd15238B'
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
    const NFT = await ethers.getContractFactory("NFT");
    const nft = await NFT.deploy("Test", "TEST", exchangeAddress[network.name], "");
    await nft.deployed();
    
    console.log("Deployed NFT Address: " + nft.address);

    console.log("-------Verifying-----------");
    try {
      // verify
      await run("verify:verify", {
        address: nft.address,
        constructorArguments: [
          "Test", "TEST", exchangeAddress[network.name], ""
        ],
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
