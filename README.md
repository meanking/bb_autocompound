# Autocompound

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

This repo is an autocompound.

## Technical instructions
- [Solidity](https://docs.soliditylang.org/)
- [Hardhat](https://hardhat.org/)

## Required global installation
- Project requires [Node.js](https://nodejs.org/) v12+ to run.

## Installation

Install the dependencies and devDependencies and start the server.

```sh
npm install
```

## Running the project on Development mode

Please run the following command to deploy this to the networks.

```sh
npx hardhat deploy --network [NETWORK_NAME] --tags [DEPLOY_TAG]
```

## Running the project on Production mode

Please run the following command to verify this.

```sh
npx hardhat verify [CONTRACT_ADDRESS] --network [NETWORK_NAME]
```