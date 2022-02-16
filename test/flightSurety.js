
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData
        .authorizeCaller(config.flightSuretyApp.address, true);
  });
  
  const departure = Math.floor( Date.now()/1000);
  

  

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it(`(airline) check if airline is registered on deployment`, async function () {

    // Check if airline is registered
    let result = await config.flightSuretyData.isAirline.call(config.firstAirline);
    
    assert.equal(result, true, "No Airline registered on Contract deployment")
  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it(`(airline) check if airline can pay funds after registration`, async function () {
    
    // Declare and Initialize a variable for event
    let eventFunded = false
        
    // Watch the emitted event
    await config.flightSuretyData.AirlineFunded((err, res) => {
        eventFunded = true
    })
  
    // ACT
    try {
        await config.flightSuretyData.fund(config.firstAirline, {from: config.firstAirline, value: web3.utils.toWei('10','ether')});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isFundedAirline.call(config.firstAirline); 

    // ASSERT
    assert.equal(result, true, "Airline could not go to Funded State");
    assert.equal(eventFunded, true, 'Invalid Registered event emitted')
  
  });


  it(`(airline) Only existing airline may register a new airline until there are at least four airlines registered`, async function () {
    
    // ARRANGE
    let Airline2 = accounts[2];
    let Airline3 = accounts[3];
    let Airline4 = accounts[4];
    let Airline5 = accounts[5];

    // Declare and Initialize a variable for event
    let eventRegistered = false
    let eventinApplication = false
        
    // Watch the emitted events 
    await config.flightSuretyData.AirlineRegistered((err, res) => {
        eventRegistered = true
    })
    
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(Airline2, "SecondAirline", {from: config.firstAirline});
        await config.flightSuretyData.fund(Airline2, {from: Airline2, value: web3.utils.toWei('10','ether')});

        await config.flightSuretyApp.registerAirline(Airline3, "ThirdAirline", {from: Airline2});
        await config.flightSuretyData.fund(Airline3, {from: Airline3, value: web3.utils.toWei('10','ether')});
        
        await config.flightSuretyApp.registerAirline(Airline4, "FourthAirline", {from: Airline3});
        await config.flightSuretyData.fund(Airline4, {from: Airline4, value: web3.utils.toWei('10','ether')});
        
        await config.flightSuretyApp.registerAirline(Airline5, "FifthAirline", {from: Airline4});
    }
    catch(e) {

    }
    // Check if airline is registered
    let result2 = await config.flightSuretyData.isAirline.call(Airline2);
    let result3 = await config.flightSuretyData.isAirline.call(Airline3);
    let result4 = await config.flightSuretyData.isAirline.call(Airline4);
    let check1 = await config.flightSuretyData.countRegisteredAirlines.call();
    let result5 = await config.flightSuretyData.isAirline.call(Airline5);
    
    assert.equal(result2, true, "Airline2 not registered")
    assert.equal(result3, true, "Airline3 not registered")
    assert.equal(result4, true, "Airline4 not registered")
    assert.equal(check1, 4, "Registered Airlines Counter is incorrect")
    assert.equal(result5, false, "Airline5 not in Apply State")
    assert.equal(eventRegistered, true, 'Invalid Registered event emitted')
  
  });


  it(`(airline) Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines`, async function () {
    // ARRANGE
    let Airline4 = accounts[4];
    let Airline5 = accounts[5];
    let Airline6 = accounts[6];

    // Declare and Initialize a variable for event
    let eventVoted = false
    let eventRegistered = false
        
    // Watch the emitted events
    await config.flightSuretyData.ApprovalVoting((err, res) => {
        eventVoted = true
    })
    await config.flightSuretyData.AirlineRegistered((err, res) => {
        eventRegistered = true
    })
   
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(Airline5, "FifthAirline", {from: accounts[3]});
        await config.flightSuretyApp.registerAirline(Airline6, "SixthAirline", {from: Airline4});

        await config.flightSuretyData.fund(Airline5, {from: Airline5, value: web3.utils.toWei('10','ether')});
        await config.flightSuretyApp.registerAirline(Airline6, "SixthAirline", {from: Airline5});
        await config.flightSuretyApp.registerAirline(Airline6, "SixthAirline", {from: Airline5});
    }
    catch(e) {

    }
    // Check if airline is registered
    let result1 = await config.flightSuretyData.isAirline.call(Airline5);
    let result2 = await config.flightSuretyData.isAirline.call(Airline6);
    let check1 = await config.flightSuretyData.countRegisteredAirlines.call();
    
    assert.equal(result1, true, "Airline5 not registered")
    assert.equal(result2, false, "Airline6 registered, Airline 5 approved double or consensus not working")
    assert.equal(check1, 5, "Registered Airlines Counter is incorrect")
    assert.equal(eventVoted, true, 'Invalid Vote event emitted')
    assert.equal(eventRegistered, true, 'Invalid Registered event emitted')
  
  });


  it(`(airline) check if airline can register a flight`, async function () {
    
    // Declare and Initialize a variable for event
    let eventFlightRegistered = false
        
    // Watch the emitted event eventFlightRegistered()
    await config.flightSuretyData.FlightRegistered((err, res) => {
        eventFlightRegistered = true
    })
    
    // ACT
    try {
      await config.flightSuretyApp.registerFlight( departure, "ND1309", {from: config.firstAirline});    
    }
    catch(e) {
    
    }
    
    let result = await config.flightSuretyApp.getFlightInfo.call(0, {from: config.firstAirline})  
    
    // ASSERT
    assert.equal(eventFlightRegistered, true, 'Invalid FlightRegistered event emitted')
    assert.equal(result.isRegistered, true, 'Flight is not registered')
    assert.equal(result.airline, config.firstAirline, 'Flight is not registered')
  
  });
  

  it(`(insurance) check if costumer can buy insurance`, async function () {
    
    // Declare and Initialize a variable for event
    let eventInsurancePurchased = false
        
    // Watch the emitted event InsurancePurchased()
    await config.flightSuretyData.InsurancePurchased((err, res) => {
        eventInsurancePurchased = true
    })
    
    // ACT
    try {
      await config.flightSuretyData.buyInsurance(config.firstAirline, "ND1309", departure, {from: Account[10], value: web3.utils.toWei('1','ether')});  
    }
    catch(e) {
    
    }
        
    // ASSERT
    assert.equal(eventInsurancePurchased, true, 'Invalid FlightRegistered event emitted')
  
  });

});


