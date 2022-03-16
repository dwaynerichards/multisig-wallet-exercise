/**
 * @type import('hardhat/config').HardhatUserConfig
 */
import { HardhatUserConfig, task } from "hardhat/config";

import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import { promises as fs } from "fs";

const getMnemonic = () => {
  try {
    (async () => {
      const mnemonic = await fs.readFile("./mnemonic.secret").toString().trim();
      return mnemonic;
    })();
  } catch (e) {
    // @ts-ignore
    if (defaultNetwork !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic file created for a deploy account. Try `hardhat generate` and then `hardhat account`."
      );
    }
  }
  return "";
};

const defaultNetwork = "hardhat";
const config: HardhatUserConfig = {
  defaultNetwork,
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
  },

  networks: {
    hardhat: {},
    localhost: {
      url: "http://localhost:8545",
      /*
        if there is no mnemonic, it will just use account 0 of the hardhat node to deploy
        (you can put in a mnemonic here to set the deployer locally)
      */
      // accounts: {
      //   mnemonic: mnemonic(),
      // },
    },
    rinkeby: {
      url: process.env.RINKEBY_INFURA_KEY,
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    kovan: {
      url: process.env.KOVAN_INFURA_KEY,
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    mainnet: {
      url: process.env.MAINNET_INFURA_KEY,
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    ropsten: {
      url: "https://ropsten.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad",
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    goerli: {
      url: "https://goerli.infura.io/v3/460f40a260564ac4a4f4b3fffb032dad",
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    xdai: {
      url: "https://rpc.xdaichain.com/",
      gasPrice: 1000000000,
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
    matic: {
      url: "https://rpc-mainnet.maticvigil.com/",
      gasPrice: 1000000000,
      accounts: {
        mnemonic: getMnemonic(),
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.6.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    cache: "./generated/cache",
    artifacts: "./generated/artifacts",
    deployments: "./generated/deployments",
  },
};
