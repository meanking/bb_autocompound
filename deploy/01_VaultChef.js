module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy("VaultChef", {
    from: deployer,
    log: true,
    args: [
      'BB VaultChef',
      'BBBaseXToken'
    ],
    deterministicDeployment: false,
  })
}

module.exports.tags = ["VaultChef"]