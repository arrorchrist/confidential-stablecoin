import { expect } from "chai";
import { ethers, fhevm } from "hardhat";
import { FhevmType } from "@fhevm/hardhat-plugin";

describe("ConfidentialStablecoin", function () {
  let token: any, addr: string;
  let owner: any, alice: any, bob: any;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ConfidentialStablecoin");
    token = await Factory.deploy();
    addr = await token.getAddress();

    // allowlist
    await (await token.setAllowed(alice.address, true)).wait();
    await (await token.setAllowed(bob.address, true)).wait();

    // mint 1,000,000 units (1 USDC = 1e6) to Alice
    await (await token.mint(alice.address, 1_000_000)).wait();
  });

  it("encrypted balance is non-zero for Alice after mint", async () => {
    const encBal = await token.balanceOf(alice.address);
    expect(encBal).to.not.eq(ethers.ZeroHash); // ciphertext exists
  });

  it("confidential transfer succeeds when enough balance", async () => {
    const encAmt = await fhevm.createEncryptedInput(addr, alice.address).add64(200_000).encrypt();

    const tx = await token
      .connect(alice)
      .transfer(bob.address, encAmt.handles[0], encAmt.inputProof);
    await tx.wait();

    const encBob = await token.balanceOf(bob.address);
    const bobClear = await fhevm.userDecryptEuint(FhevmType.euint64, encBob, addr, bob);
    expect(bobClear).to.eq(200_000);
  });

  it("fail-closed when amount > balance (executed=0)", async () => {
    // Alice tries to send >1_000_000
    const encAmt = await fhevm.createEncryptedInput(addr, alice.address).add64(2_000_000).encrypt();

    const executed = await token
      .connect(alice)
      .transfer.staticCall(bob.address, encAmt.handles[0], encAmt.inputProof);

    // decrypt executed result from view-return
    const dec = await fhevm.userDecryptEuint(FhevmType.euint64, executed, addr, alice);
    expect(dec).to.eq(0);
  });
});
