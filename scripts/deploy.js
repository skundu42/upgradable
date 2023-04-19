
const { ethers, upgrades } = require("hardhat");


async function main() {
  const Greeter = await ethers.getContractFactory("Greeter");
  const greeter = await upgrades.deployProxy(
    Greeter, 
    [], 
    {
      initializer: "__Greeter_init",
    }
  );

  await greeter.deployed();

  console.log("Greeter deployed to:", greeter.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});