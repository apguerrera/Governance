# Optino Governance DAO Smart Contracts

Status: **Work In Progress**

The Optino Governance (OptinoGov) smart contract is the Decentralised Autonomous Organisation (DAO) that operates the Optino Vending Machine.

Optino Governance token (OGToken) holders lock their OGTokens into the OptinoGov smart contract to submit and vote on proposals. If successful, the proposal will be executed, e.g., the minting of new OGTokens, the burning of staked tokens, and setting of fee rates.

When OGTOkens are locked into the OptinoGov smart contract, the equivalent number of Optino Governance Dividend token (OGDToken) are minted. These tokens will accrue fees generated by the Optino Vending Machine.

Following are the main smart contracts:

* [contracts/OptinoGov.sol](contracts/OptinoGov.sol) - [flattened](flattened/OptinoGov_flattened.sol)
* [contracts/OGToken.sol](contracts/OGToken.sol) - [flattened](flattened/OGToken_flattened.sol)
* [contracts/OGDToken.sol](contracts/OGDToken.sol) - [flattened](flattened/OGDToken_flattened.sol)

See also:

* https://wiki.optino.io

<br />

<hr />

### Remix

To test out these smart contracts in [Remix](http://remix.ethereum.org/), copy the contents of the files above into the same file names within Remix. Comment out the local `import ".\{file.sol}"` and uncomment the GitHub `import "https://github.com/ogDAO/Governance/blob/master/contracts/{file}.sol";`.

<br />

<hr />

### Testing

#### Clone Repository
Check out this repository into your projects subfolder:

```
git clone https://github.com/ogDAO/Governance.git
cd Governance
```

<br />

#### Install And Run Go Ethereum

Install [Go-Ethereum](https://github.com/ethereum/go-ethereum) (also known as `geth`) on your local computer to run a development blockchain node for testing. Or install and use [Ganache](https://www.trufflesuite.com/ganache) instead.

If you have installed `geth`, run:

```
./00_runGeth.sh
./01_unlockAndFundAccounts.sh
```

You may need to `chmod 700 00_runGeth.sh 01_unlockAndFundAccounts.sh` before being able to execute it.

<br />

#### Install Truffle


If not already installed, you will need [NPM](https://www.npmjs.com/). [NVM](https://github.com/nvm-sh/nvm) may take away some of your NPM versioning pain.

You will need to install [Truffle](https://github.com/trufflesuite/truffle):

```
npm install -g truffle
```

<br />

#### Install Truffle Flattener And Flatten Solidity Files

You may want to to install [Truffle Flattener](https://github.com/nomiclabs/truffle-flattener) using the command:

```
npm install -g truffle-flattener
./10_flattenSolidityFiles.sh
```

The flattened files can be found in the [./flattened/](./flattened/) subdirectory.

<br />

#### Install Other Modules

You will need the following modules installed:

```
npm install --save web3@1.2.1
npm install --save ethers
npm install --save eth-sig-util
npm install --save bignumber.js
npm install --save truffle-assertions
```

<br />

#### Compile

```
truffle compile
```

<br />

#### Run OptinoGov Tests

```
20_testOptinoGov.sh
```

You may need to `chmod 700 20_testOptinoGov.sh` before being able to execute it.

The latest output generated from the script [test/TestOptinoGov.test.js](test/TestOptinoGov.test.js) can be found in [results/TestOptinoGov.txt](results/TestOptinoGov.txt).


<br />

#### Run OGDToken Tests

```
30_testOGDToken.sh
```

You may need to `chmod 700 30_testOGDToken.sh` before being able to execute it.

The latest output generated from the script [test/TestOGDToken.test.js](test/TestOGDToken.test.js) can be found in [results/TestOGDToken.txt](results/TestOGDToken.txt).

The tests are roughly:

* Mint 10,000 OGD tokens for User{1..3}
* Owner approve 100 FEE0 for OGToken to spend
* Owner deposits dividends of 100 FEE0 and 10 ETH
* User1 dummy transfer to same account
* User{1..3} withdraw 33.333333333333333333 FEE0 and 3.333333333333333333 ETH
* Owner adds FEE1 and FEE2 as dividend tokens
* Owner approve 1,000 FEE1 and 10,000 FEE2 for OGToken to spend
* Owner deposits dividends of 1,000 FEE1 and 10,000 FEE2
* User{1..3} withdraw 333.333333333333333333 FEE1 and 3333.333333333333333333 FEE2

<br />

#### Debug

```
truffle debug {txHash}
```

<br />

#### Migrate

```
truffle migrate [--reset]
```

<br />

<br />

Enjoy!

(c) The Optino Project 2020. GPLv2


npm install --save-dev @nomiclabs/buidler
npm install --save-dev @nomiclabs/buidler-waffle
npm install --save-dev @nomiclabs/buidler-waffle ethereum-waffle chai @nomiclabs/buidler-ethers ethers

npm install --save-dev @nomiclabs/buidler-waffle@^2.0.0 ethereum-waffle@^3.0.0 chai@^4.2.0 @nomiclabs/buidler-ethers@^2.0.0 ethers@^5.0.0

npx buidler accounts
npx buidler node
npx buidler compile
vi buidler.config.js
npx buidler clean
npx buidler console
npx buidler test
npx buidler test test/TestOGDToken.js
