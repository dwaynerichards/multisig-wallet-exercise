import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { parseEther } from "ethers/lib/utils";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getNamedAccounts, deployments, getUnnamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const accounts = await getUnnamedAccounts();
  accounts.splice(4);
  //contract is deployed with  3 args in constructor
  //5 accounts addresses, 3 confirmations required, and a daily limit of 2 eth
  const multiSigresult = await deploy("MultiSigWalletWithDailyLimit", {
    from: deployer,
    args: [accounts, 3, parseEther("2")],
    log: true,
  });

  const MultiSigWithLimit = await ethers.getContractAt("MultiSigWalletWithDailyLimit", multiSigresult.address);
  const signer = await ethers.getSigner(deployer);
  //10 ether is send to the wallet after instantiation
  const txObj = { to: MultiSigWithLimit.address, value: parseEther("10") };
  const tx = await signer.sendTransaction(txObj);
  await tx.wait();
};
export default func;
func.tags = ["MultiSigWalletWithDailyLimit"];
