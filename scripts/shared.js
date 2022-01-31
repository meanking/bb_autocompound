const { ethers } = require("hardhat");
const { BigNumber } = ethers;

function getBigNumber(amount, decimal = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimal));
}

module.exports = {
  getBigNumber,
};