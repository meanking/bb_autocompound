module.exports = async function ({
    ethers,
    getNamedAccounts,
    deployments,
    getChainId,
  }) {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
  
    const vaultChef        = await deployments.get("VaultChef");
    const wantAddress      = "0xd393b1e02da9831ff419e22ea105aae4c47e1253"; // DAI
    const aTokenAddress    = "0x639cB7b21ee2161DF9c882483C9D55c90c20Ca3e"; // amDAI
    const debtTokenAddress = "0x6d29322ba6549b95e98e9b08033f5ffb857f19c5"; // variableDebtmDAI
    const earnedAddress    = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889"; // WMATIC
    const usdcAddress      = "0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747"; // USDC
    const bbankAddress     = "0x63F7B7D85F9B02aD94c93A138a5b7508937b5942"; // BBANK

    await deploy("StrategyAave", {
      from: deployer,
      log: true,
      args: [
        vaultChef.address,
        wantAddress,
        aTokenAddress,
        debtTokenAddress,
        earnedAddress,
        [earnedAddress, usdcAddress],
        [earnedAddress, bbankAddress],
        [earnedAddress, wantAddress],
      ],
      deterministicDeployment: false,
    });
  };
  
  module.exports.tags = ["StrategyAave"];
  module.exports.dependencies = ["VaultChef"];
  