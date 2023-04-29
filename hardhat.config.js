/** @type import('hardhat/config').HardhatUserConfig */

require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  networks: {
    hardhat: {
    },
    liberty: {
      url: "https://liberty20.shardeum.org/",
      accounts:[``],
      gasPrice:1000
    },
    sphinx: {
        url: "https://sphinx.shardeum.org/",
        accounts: [``]
        },
        mumbai: {
          url: "https://rpc.ankr.com/polygon_mumbai",
          accounts: [``]
          }
  },
  solidity: "0.8.4",
};
