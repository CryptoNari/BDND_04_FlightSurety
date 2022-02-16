import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'))
);

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

const REGISTER_ORACLES = 80 // Number of Oracles
const STATUS_CODES = [10, 20, 30, 40, 50];
let regOracles = [] // registered Oracles

web3.eth.defaultAccount = web3.eth.accounts[0];


main();

async function main() {
  const accounts = await web3.eth.getAccounts();
  const oracleAdresses = accounts.slice(10, REGISTER_ORACLES + 10);

  await flightSuretyData.methods.authorizeCaller(config.appAddress, true).send({
    from: accounts[0]
  })

  await registerOracles(oracleAdresses);

  flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    oracleRespond(
      event.returnValues.index,
      event.returnValues.airline,
      event.returnValues.flight,
      event.returnValues.timestamp
    )

    if (error) console.log(error)
  });

}


async function registerOracles(oracleAdresses) {

  for (const account of oracleAdresses) {

    let randomStatus = STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)];
   
    await flightSuretyApp.methods.registerOracle().send({
      from: account,
      value: web3.utils.toWei("1", "ether"),
      gas: 3000000
    });

    let idx = await flightSuretyApp.methods
            .getMyIndexes()
            .call({ from: account });
    
    regOracles.push({ account, idx, randomStatus });
    
  };
  console.log(`Oracles Registered: ${regOracles.length}`);
  
}


async function oracleRespond(index, airline, flight, departure) {
  const respondingOracles = [];
  for (const oracle of regOracles) {

    if (oracle.idx[0] === index || oracle.idx[1] === index || oracle.idx[2] === index) {
      respondingOracles.push(oracle);
    }
    
  }
  
  
  respondingOracles.forEach( (oracle) => {    
      flightSuretyApp.methods
        .submitOracleResponse(index, airline, flight, departure, oracle.randomStatus)
        .send({ from: oracle.account, gas: 300000 })
        .then(() => {
          // console.log("Oracle response:" + oracle.randomStatus);
      })
      .catch((err) => console.log(`Rejected: ${err}`));
  });
  

}


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


