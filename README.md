# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

The Current State of the DApp includes just a testing purpose of buying an insurance and getting the payout after LATE_AIRLINE State.

Feedbacks regarding UI/UX are not implemented yet.

## Install

### Requirements

Truffle v5.0.2 (core: 5.0.2)

Solidity - ^0.4.24 (solc-js)

Node v10.7.0


This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client  (truffle tests)

In the first terminal start ganache:

`ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -a 100 -e 1000`

In a second terminal run:

`truffle compile`

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

## DApp Client 

In the first terminal start/restart ganache:

`ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -a 100 -e 1000`

In a second terminal run to start the Dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

In a third terminal start the Server for Oracle functionality:

`npm run server`

Wait for the oracles to register.
In the server log a message will inform you
"Oracles Registered: 80" 

## Instructions to test the Insurance functions with the Dapp

-   First check the correct setup on the contract page and see if Contract is operational
-   Open the Insurances Form on the Navigation at the top
-   Select a flight and Press the "Buy Insurance" Button (no feedback)
-   after every command you can reload the Insurance table below with the "Show/Update Insurances" Button
-   in the Insurance Table you can update the flight status with "Get flight status"
-   "Show/Update Insurances" is required to show the updated status
    -   for testing purpose you can request the flight status over and over again until you get the "AIRLINE_LATE" response
-   When AIRLINE_LATE the button "Claim Insurance" is available.
-   Check the Balances at the top if Insuree gets credited.
-   Finally payout and Verify Balances

## TODO

### After project passing
    -   Use Dapp Initialized accounts to populate
    -   Complete DApp UI/UX
    -   Work on feedback loops to UI/UX (returns contract calls)
        -   read on gas effieciency regarding this
        -   read and show submitted events
    -   Move more/all interaction to AppContract
    -   InsuranceState "Payable" logic --> find best solution  

## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)