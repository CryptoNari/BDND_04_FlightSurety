import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';



let config = Config['localhost'];
let web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'))
);



const REGISTER_ORACLES = 80 // Number of Oracles
const STATUS_CODES = [10, 20, 30, 40, 50];
let regOracles = [] // registered Oracles


web3.eth.defaultAccount = web3.eth.accounts[0];


let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

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
    console.log(event)
    if (error) console.log(error)
  });

  flightSuretyData.events.FlightStatusProcessed({
    fromBlock: 0
  }, function (error, event) {
    console.log(event.event)
    console.log(event.returnValues.sender)
    if (error) console.log(error)
  });

}



async function registerOracles(oracleAdresses) {

  for (const account of oracleAdresses) {

    let randomStatus = STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)];
   

    // console.log("Test");
    await flightSuretyApp.methods.registerOracle().send({
      from: account,
      value: web3.utils.toWei("1", "ether"),
      gas: 3000000
    });
    //console.log(`Oracle: ${account}`);
    let idx = await flightSuretyApp.methods
            .getMyIndexes()
            .call({ from: account });
    
    regOracles.push({ account, idx, randomStatus });
    //console.log(regOracles)
  };
  console.log(`Oracles Registered: ${regOracles.length}`);
  
}

async function oracleRespond(index, airline, flight, departure) {
  // console.log(`RESPOND :::: index: ${index}, airline: ${airline}, flight: ${flight}, departure: ${departure} `);
  const respondingOracles = [];
  for (const oracle of regOracles) {

    if (oracle.idx[0] === index || oracle.idx[1] === index || oracle.idx[2] === index) {
      respondingOracles.push(oracle);
    }
    
  }
  // console.log(`IDxs: ${respondingOracles.length}`);
  
  respondingOracles.forEach( (oracle) => {
    
    
      flightSuretyApp.methods
        .submitOracleResponse(index, airline, flight, departure, oracle.randomStatus)
        .send({ from: oracle.account, gas: 300000 })
        .then(() => {
          console.log("Oracle response:" + oracle.randomStatus);
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


