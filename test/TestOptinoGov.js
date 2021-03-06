const { ZERO_ADDRESS, Data } = require('./helpers/common');
const { expect } = require("chai");
const BigNumber = require('bignumber.js');
const util = require('util');

let OGToken;
let OGDToken;
let TestToken;
let OptinoGov;
let data;
const verbose = false;

describe("TestOptinoGov", function() {
  beforeEach("Setup", async function() {
    OGToken = await ethers.getContractFactory("OGToken");
    OGDToken = await ethers.getContractFactory("OGDToken");
    TestToken = await ethers.getContractFactory("TestToken");
    OptinoGov = await ethers.getContractFactory("OptinoGov");
    data = new Data();
    await data.init();

    console.log("        --- Setup 1 - Deploy OGToken, OGDToken, FEE0, then OptinoGov ---");
    const setup1a = [];
    setup1a.push(OGToken.deploy("OG", "Optino Governance", 18, data.owner, new BigNumber("40000").shiftedBy(18).toFixed(0)));
    setup1a.push(OGDToken.deploy("OGD", "Optino Governance Dividend", 18, data.owner, new BigNumber("0").shiftedBy(18).toFixed(0)));
    setup1a.push(TestToken.deploy("FEE0", "Fee0", 18, data.owner, new BigNumber("1000").shiftedBy(18).toFixed(0)));
    const [ogToken, ogdToken, fee0Token] = await Promise.all(setup1a);
    const setup1b = [];
    setup1b.push(OptinoGov.deploy(ogToken.address, ogdToken.address));
    const [optinoGov] = await Promise.all(setup1b);
    await data.setOptinoGovData(ogToken, ogdToken, fee0Token, optinoGov);
    await data.printTxData("ogToken.deployTransaction", ogToken.deployTransaction);
    await data.printTxData("ogdToken.deployTransaction", ogdToken.deployTransaction);
    await data.printTxData("fee0Token.deployTransaction", fee0Token.deployTransaction);
    await data.printTxData("optinoGov.deployTransaction", optinoGov.deployTransaction);
    if (verbose) {
      await data.printBalances();
    }

    console.log("        --- Setup 2 - OGDToken.addDividendToken([ETH, FEE0]), OGDToken mint(...) permissioning ---");
    const setup2 = [];
    setup2.push(data.ogdToken.addDividendToken(ZERO_ADDRESS));
    setup2.push(data.ogdToken.addDividendToken(fee0Token.address));
    setup2.push(ogToken.setPermission(data.optinoGov.address, 1, true, 0));
    setup2.push(data.ogdToken.setPermission(data.optinoGov.address, 1, true, 0));
    setup2.push(data.ogdToken.setPermission(data.optinoGov.address, 2, true, 0));
    const [addDividendToken0, addDividendToken1, setPermission1, setPermission2, setPermission3] = await Promise.all(setup2);
    await data.printTxData("addDividendToken0", addDividendToken0);
    await data.printTxData("addDividendToken1", addDividendToken1);
    await data.printTxData("setPermission1", setPermission1);
    await data.printTxData("setPermission2", setPermission2);
    await data.printTxData("setPermission3", setPermission3);
    if (verbose) {
      await data.printBalances();
    }

    console.log("        --- Setup 3 - Transfer OGTokens, User{1..3} approve 2,000 OGTokens to OptinoGov, Owner approve 2,000 FEE0 tokens to OGDToken, Transfer OGToken and OGDToken ownership to OptinoGov ---");
    const ogTokens = new BigNumber("10000").shiftedBy(18);
    const approveTokens = new BigNumber("2000").shiftedBy(18);
    const setup3 = [];
    setup3.push(ogToken.transfer(data.user1, ogTokens.toFixed(0)));
    setup3.push(ogToken.transfer(data.user2, ogTokens.toFixed(0)));
    setup3.push(ogToken.transfer(data.user3, ogTokens.toFixed(0)));
    setup3.push(ogToken.connect(data.user1Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
    setup3.push(ogToken.connect(data.user2Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
    setup3.push(ogToken.connect(data.user3Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
    setup3.push(fee0Token.approve(data.ogdToken.address, approveTokens.toFixed(0)));
    setup3.push(ogToken.transferOwnership(data.optinoGov.address));
    setup3.push(data.ogdToken.transferOwnership(data.optinoGov.address));
    const [transfer1, transfer2, transfer3, approve1, approve2, approve3, approve4, transferOwnership1, transferOwnership2] = await Promise.all(setup3);
    await data.printTxData("transfer1", transfer1);
    await data.printTxData("transfer2", transfer2);
    await data.printTxData("transfer3", transfer3);
    await data.printTxData("approve1", approve1);
    await data.printTxData("approve2", approve2);
    await data.printTxData("approve3", approve3);
    await data.printTxData("approve4", approve4);
    await data.printTxData("transferOwnership1", transferOwnership1);
    await data.printTxData("transferOwnership2", transferOwnership2);
    await data.printBalances();

    console.log("        --- Setup Completed ---");
    console.log("");
  });

  describe("TestOptinoGov - Standard Workflow #0", function() {
    it("Standard Workflow #0", async function() {
      console.log("        --- Test 1 - User{1,2} delegate to User3---");
      const test1 = [];
      test1.push(data.optinoGov.connect(data.user1Signer).delegate(data.user3));
      test1.push(data.optinoGov.connect(data.user2Signer).delegate(data.user3));
      const [delegate1, delegate2] = await Promise.all(test1);
      await data.printTxData("delegate1", delegate1);
      await data.printTxData("delegate2", delegate2);
      await data.printBalances();

      console.log("        --- Test 2 - User{1..3} commit OGTokens for {5, 50, 500} seconds duration ---");
      const tokensToCommit = new BigNumber("1000").shiftedBy(18);
      const test2 = [];
      test2.push(data.optinoGov.connect(data.user1Signer).commit(tokensToCommit.toFixed(0), 5));
      test2.push(data.optinoGov.connect(data.user2Signer).commit(tokensToCommit.toFixed(0), 50));
      test2.push(data.optinoGov.connect(data.user3Signer).commit(tokensToCommit.toFixed(0), 500));
      const [commit1, commit2, commit3] = await Promise.all(test2);
      await data.printTxData("commit1", commit1);
      await data.printTxData("commit2", commit2);
      await data.printTxData("commit3", commit3);
      if (verbose) {
        await data.printBalances();
      }

      console.log("        --- Test 3 - User{2} commit again for {55} seconds duration ---");
      const test3 = [];
      test3.push(data.optinoGov.connect(data.user2Signer).commit(tokensToCommit.toFixed(0), 55));
      const [commit4] = await Promise.all(test3);
      await data.printTxData("commit4", commit4);
      await data.printBalances();

      console.log("        --- Test 4 - User1 collecting rewards, user2 collecting and committing rewards leaving duration unchanged, user3 collecting and committing rewards and extending duration ---");
      const test4 = [];
      test4.push(data.optinoGov.connect(data.user1Signer).collectReward(false, 0));
      test4.push(data.optinoGov.connect(data.user2Signer).collectReward(true, 0));
      test4.push(data.optinoGov.connect(data.user3Signer).collectReward(true, 5000));
      const [collectReward1, collectReward2, collectReward3] = await Promise.all(test4);
      await data.printTxData("collectReward1", collectReward1);
      await data.printTxData("collectReward2", collectReward2);
      await data.printTxData("collectReward3", collectReward3);
      if (verbose) {
        await data.printBalances();
      }

      console.log("        --- Test 5 - Owner collecting rewards on behalf of user1 for a % fee ---");
      data.pause("Waiting", 5);
      const test5 = [];
      test5.push(data.optinoGov.collectRewardFor(data.user1));
      const [collectRewardFor1] = await Promise.all(test5);
      await data.printTxData("collectRewardFor1", collectRewardFor1);
      await data.printBalances();

      console.log("        --- Test 6 - Owner deposits dividends of 10 ETH and 100 FEE ---");
      const depositFee1Tokens = new BigNumber("10").shiftedBy(18);
      const depositFee2Tokens = new BigNumber("100").shiftedBy(18);
      const test6 = [];
      test6.push(data.ogdToken.depositDividend(ZERO_ADDRESS, depositFee1Tokens.toFixed(0), { value: depositFee1Tokens.toFixed(0) }));
      test6.push(data.ogdToken.depositDividend(data.fee0Token.address, depositFee2Tokens.toFixed(0)));
      const [depositDividendFee1, depositDividendFee2] = await Promise.all(test6);
      await data.printTxData("depositDividendFee1", depositDividendFee1);
      await data.printTxData("depositDividendFee2", depositDividendFee2);
      if (verbose) {
        await data.printBalances();
      }

      console.log("        --- Test 7 - User{1..3} withdraw ETH and FEE dividends ---");
      const test7 = [];
      test7.push(data.ogdToken.connect(data.user1Signer).withdrawDividends());
      test7.push(data.ogdToken.connect(data.user2Signer).withdrawDividends());
      test7.push(data.ogdToken.connect(data.user3Signer).withdrawDividends());
      const [withdrawDividends1, withdrawDividends2, withdrawDividends3] = await Promise.all(test7);
      await data.printTxData("withdrawDividends1", withdrawDividends1);
      await data.printTxData("withdrawDividends2", withdrawDividends2);
      await data.printTxData("withdrawDividends3", withdrawDividends3);
      await data.printBalances();

      console.log("        --- Test Completed ---");
      console.log("");

      // const user1Fee1Balance = await fee1Token.balanceOf(data.user1);
      // console.log("user1Fee1Balance: " + user1Fee1Balance);
      // expect(new BigNumber(user1Fee1Balance.toString()).toFixed(0)).to.equal(new BigNumber("333.333333333333333333").shiftedBy(18).toFixed(0));

      // const Greeter = await ethers.getContractFactory("Greeter");
      // const greeter = await Greeter.deploy("Hello, world!");
      //
      // await greeter.deployed();
      // expect(await greeter.greet()).to.equal("Hello, world!");
      //
      // await greeter.setGreeting("Hola, mundo!");
      // // await greeter.connect(data.user1).setGreeting("Hola, mundo!");
      // expect(await greeter.greet()).to.equal("Hola, mundo!");

      // await ethers.provider.getLogs({}).then((data) => {
      //   console.log("getLogs: " + util.inspect(data));
      // });
    });
  });

  describe.only("TestOptinoGov - Workflow #1", function() {
    it("Workflow #1", async function() {
      console.log("        --- Test 1 - User{1..3} commit OGTokens for {1, 1, 1} seconds duration ---");
      const tokensToCommit = new BigNumber("1000").shiftedBy(18);
      const test1 = [];
      test1.push(data.optinoGov.connect(data.user1Signer).commit(tokensToCommit.toFixed(0), 1));
      test1.push(data.optinoGov.connect(data.user2Signer).commit(tokensToCommit.toFixed(0), 1));
      test1.push(data.optinoGov.connect(data.user3Signer).commit(tokensToCommit.toFixed(0), 1));
      const [commit1, commit2, commit3] = await Promise.all(test1);
      await data.printTxData("commit1", commit1);
      await data.printTxData("commit2", commit2);
      await data.printTxData("commit3", commit3);
      await data.printBalances();

      console.log("        --- Test 2 - User{1..3} approve 2,000 OGDTokens to OptinoGov ---");
      const approveTokens = new BigNumber("2000").shiftedBy(18);
      const test2 = [];
      test2.push(data.ogdToken.connect(data.user1Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
      test2.push(data.ogdToken.connect(data.user2Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
      test2.push(data.ogdToken.connect(data.user3Signer).approve(data.optinoGov.address, approveTokens.toFixed(0)));
      test2.push(data.fee0Token.approve(data.ogdToken.address, approveTokens.toFixed(0)));
      const [approve1, approve2, approve3, approve4] = await Promise.all(test2);
      await data.printTxData("approve1", approve1);
      await data.printTxData("approve2", approve2);
      await data.printTxData("approve3", approve3);
      await data.printTxData("approve3", approve4);
      await data.printBalances();

      console.log("        --- Test 3 - Owner deposits dividends of 10 ETH and 100 FEE ---");
      const depositFee1Tokens = new BigNumber("10").shiftedBy(18);
      const depositFee2Tokens = new BigNumber("100").shiftedBy(18);
      const test3 = [];
      test3.push(data.ogdToken.depositDividend(ZERO_ADDRESS, depositFee1Tokens.toFixed(0), { value: depositFee1Tokens.toFixed(0) }));
      test3.push(data.ogdToken.depositDividend(data.fee0Token.address, depositFee2Tokens.toFixed(0)));
      const [depositDividendFee1, depositDividendFee2] = await Promise.all(test3);
      await data.printTxData("depositDividendFee1", depositDividendFee1);
      await data.printTxData("depositDividendFee2", depositDividendFee2);
      await data.printBalances();

      // console.log("        --- Test 4 - User2 transfer all to user3 ---");
      // const test4 = [];
      // test4.push(data.ogdToken.connect(data.user2Signer).transfer(data.user3, tokensToCommit.toFixed(0)));
      // const [transfer1] = await Promise.all(test4);
      // await data.printTxData("transfer1", transfer1);
      // await data.printBalances();
      //
      // console.log("        --- Test 5 - User{1..3} withdraw ETH and FEE dividends ---");
      // const test5 = [];
      // test5.push(data.ogdToken.connect(data.user1Signer).withdrawDividends());
      // test5.push(data.ogdToken.connect(data.user2Signer).withdrawDividends());
      // test5.push(data.ogdToken.connect(data.user3Signer).withdrawDividends());
      // const [withdrawDividends1, withdrawDividends2, withdrawDividends3] = await Promise.all(test5);
      // await data.printTxData("withdrawDividends1", withdrawDividends1);
      // await data.printTxData("withdrawDividends2", withdrawDividends2);
      // await data.printTxData("withdrawDividends3", withdrawDividends3);
      // await data.printBalances();

      console.log("        --- Test 4 - User{1..3} uncommit OGTokens ---");
      const tokensToUncommit = new BigNumber("100").shiftedBy(18);
      const test4 = [];
      // data.pause("Waiting", 5);
      test4.push(data.optinoGov.connect(data.user1Signer).uncommit(tokensToUncommit.toFixed(0)));
      test4.push(data.optinoGov.connect(data.user2Signer).uncommit(tokensToUncommit.toFixed(0)));
      test4.push(data.optinoGov.connect(data.user3Signer).uncommit(tokensToUncommit.toFixed(0)));
      const [uncommit1, uncommit2, uncommit3] = await Promise.all(test4);
      await data.printTxData("uncommit1", uncommit1);
      await data.printTxData("uncommit2", uncommit2);
      await data.printTxData("uncommit3", uncommit3);
      await data.printBalances();

      console.log("        --- Test Completed ---");
      console.log("");
    });
  });

  describe.skip("TestOptinoGov - Workflow #2", function() {
    it("Workflow #2", async function() {
      console.log("Workflow #2");
    });
  });
});
