module.exports = async function ({
  ethers,
  getNamedAccounts,
  deployments,
  getChainId,
}) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const vaultChef     = await deployments.get("VaultChef");
  const pid           = 3;
  const wantAddress   = "0x26ba46ba65b16e8870a1a546e13426cfe454e41b"; // DAI_GAINS on rinkeby
  const sushiAddress  = "0xd1d34c82bb30a81cbd22c9000a95bea9dabdcc5c"; // Sushi address on rinkeby - Gained address
  const WETH          = "0xc778417e063141139fce010982780140aa0cd5ab"; // WETH address on rinkeby
  const bbankAddress  = "0xADa17be1b58891d8e1FDA75F73f93152969F6fda"; // BBank Address on rinkeby
  const token0Address = "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735"; // DAI on rinkeby
  const token1Address = "0x92153Bb4d23f750f7C03F931D3e06441c5EC0b4f"; // GAINS on rinkeby
  await deploy("StrategySushiSwap", {
    from: deployer,
    log: true,
    args: [
      vaultChef.address,
      pid,
      wantAddress,
      sushiAddress,
      [bbankAddress, WETH],
      [sushiAddress, bbankAddress],
      [WETH, bbankAddress],
      [sushiAddress, token0Address],
      [sushiAddress, token1Address],
      [WETH, token1Address],
      [WETH, token1Address],
    ],
    deterministicDeployment: false,
  });
};

module.exports.tags = ["StrategySushiswap"];
module.exports.dependencies = ["VaultChef"];
