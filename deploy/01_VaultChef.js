// const hh = require("hardhat")

// async function main() {
//   const VaultChef = await hh.ethers.getContractFactory("VaultChef")
//   const VC = await VaultChef.deploy()

//   await VC.deployed()

//   console.log("VaultChef was deployed to :: ", VC.address, " successfully.");
// }

// main()
//   .then(() => process.exit(0))
//   .catch(error => {
//     console.error(error);
//     process.exit(1);
//   });

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const owner = deployer

  await deploy("VaultChef", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
  })
}

module.exports.tags = ["VaultChef"]