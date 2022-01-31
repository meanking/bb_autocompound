// This is for DCAU_LINK LP on rinkeby, pool id is 3
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
  const wantAddress   = "0x63214d4ef18b74a1b43c6b521f34b830c261aec6"; // HAROLDMARS_PAPR on rinkeby
  const sushiAddress  = "0xd1d34c82bb30a81cbd22c9000a95bea9dabdcc5c"; // Sushi address on rinkeby - Gained address
  const WETH          = "0xc778417e063141139fce010982780140aa0cd5ab"; // WETH address on rinkeby
  const bbankAddress  = "0xADa17be1b58891d8e1FDA75F73f93152969F6fda"; // BBank Address on rinkeby
  const token0Address = "0x733051cb7fb3ffbcc693e0a89cb72edc2cd19f05"; // HAROLDMARS on rinkeby
  const token1Address = "0x7bf5f00adf1a71bad1fdbb916e4f0cc229f9c541"; // PAPR on rinkeby
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
