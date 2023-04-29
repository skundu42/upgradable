import { constants, utils } from "ethers";
import { ethers, upgrades } from "hardhat";

async function main(){



const SubscriptionModule = await ethers.getContractFactory("SubscriptionModule");

const subscriptionModule = await upgrades.deployProxy(
  SubscriptionModule,
  [2000, 3600 * 24 * 30, "0x293b6aE85202D24FEA1033410e40096A5Fbd73C9", "0x9Bd31410Ed25BaE431e512E09815811A5244FD44"],
  {
    initializer: "__subscription_init",
  }
);
console.log(subscriptionModule)

await subscriptionModule.deployed();

console.log("subscriptionModule deployed to:", subscriptionModule.address);

};

main();