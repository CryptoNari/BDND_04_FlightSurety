pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /**************************************************************************/
    /*                             DATA VARIABLES                             */
    /**************************************************************************/

    address private contractOwner; // Account used to deploy contract
    address private firstAirline = 0xf17f52151EbEF6C7334FAD080c5704D77216b732; 
    // Blocks all state changes throughout the contract if false
    bool private operational = true;

    /***********************************************/
    /*               AIRLINE VARIABLES             */
    /***********************************************/

    mapping(address => bool) private authorizedCallers;
    uint256 authAirlines = 0; // Airlines authorized for consensus voting
    uint256 regAirlines = 0; // Airlines registered 

    enum AirlineState {
        Init,
        Application,
        Registered,
        Funded
    }

    struct Airline {
        AirlineState status;
        string name;
        mapping(address => bool) voters;
        uint voteCount;
    }

    mapping(address => Airline) airlines;

    /***********************************************/
    /*               FLIGHT VARIABLES              */
    /***********************************************/

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 departure;
        uint256 lastUpdate;      
        address airline;
        string flightCode;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] registeredFlights;

    /***********************************************/
    /*              INSURANCE VARIABLES            */
    /***********************************************/

    enum InsuranceState {
        Init,
        Active,
        Payable,
        Closed,
        Received
    }
    
    struct Insurance {
        InsuranceState status;
        uint256 insuranceAmount;
        uint256 insurancePayout;
    }

    mapping(address=> mapping(bytes32 => Insurance)) insurances;
    mapping(address=> uint256) passengerBalances;

    uint private constant MAX_INSURANCE_AMOUNT = 1 ether;
    

    /**************************************************************************/
    /*                           EVENT DEFININTIONS                           */
    /**************************************************************************/
    
    event ApprovalVoting (address airlineAddress, uint votes, uint regAirlines);
    event AirlineRegistered (address airlineAddress, uint regAirlines);
    event AirlineFunded (address airlineAddress);
    
    event FlightStatusProcessed(bool sender, string flight, uint8 statusCode);
    event FlightRegistered(bytes32 flightKey);
    
    event InsurancePurchased(address insuree,string flight);
    event PayoutToInsuree(address insuree, string flight);
    event InsureePayout(address insuree);
    
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      First airline gets registered
    */
    constructor()         
       public 
    {
        contractOwner = msg.sender;
        // Add Firts Airline on Contract deployment
        airlines[firstAirline] = Airline({
            status: AirlineState.Registered,
            name: "FirstAirline",
            voteCount: 0
        });
        regAirlines = regAirlines.add(1);

        // Add sample flights on Contract deployment
        bytes32 key1 = getFlightKey(firstAirline, "Flight1", now + 1 days);
        bytes32 key2 = getFlightKey(firstAirline, "Flight2", now + 2 days);
        bytes32 key3 = getFlightKey(firstAirline, "Flight3", now + 3 days);
        
        flights[key1]= Flight(true, 0, now + 1 days, now, firstAirline, "Flight1");
        registeredFlights.push(key1);
        flights[key2]= Flight(true, 0, now + 2 days, now, firstAirline, "Flight2");
        registeredFlights.push(key2);
        flights[key3]= Flight(true, 0, now + 3 days, now, firstAirline, "Flight3");
        registeredFlights.push(key3);
    }

    /**************************************************************************/
    /*                            FUNCTION MODIFIERS                          */
    /**************************************************************************/

    /**
    * @dev Modifier that requires the "operational" bool variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be 
    *      the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the an authorised "ContractCaller" 
    *      account to be the function caller
    */
    modifier requireAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender], "Caller is not authorised");
        _;
    }

    /**************************************************************************/
    /*                             UTILITY FUNCTIONS                          */
    /**************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    *      When operational mode is disabled, all write transactions except 
    *      for this one will fail
    */    
    function setOperatingStatus(bool _mode) external requireContractOwner {
        operational = _mode;
    }


    /**
    * @dev Sets authorized ContractCaller Addresses
    *
    */
    function authorizeCaller(address _authCaller, bool _status) 
        external
        requireContractOwner
    {
        authorizedCallers[_authCaller] = _status;
    }


    /**************************************************************************/
    /*                          SMART CONTRACT FUNCTIONS                      */
    /**************************************************************************/ 
    function isFundedAirline(address _airline) external view returns (bool) {
        return (airlines[_airline].status == AirlineState.Funded);       
    }
    
    // App.registerAirline()
    function isAirline(address _airline) external view returns (bool) {
        AirlineState status = airlines[_airline].status;
        if ( status == AirlineState.Registered || status == AirlineState.Funded)
            return true;
    }

    // App.registerAirline()
    function countRegisteredAirlines() external view returns (uint) {
        return regAirlines;
    }

    /// App.registerAirline()
    function countCurrentVotes(address _airline) external view returns (uint) {
        return airlines[_airline].voteCount;
    }

    // App.registerAirline()
    function doubleVoteCheck(address _airline, address _caller)
        external
        view
        returns (bool)
    {
        return airlines[_airline].voters[_caller];
    }

    // Data.registerAirline()
    function airlineFirstAction(address _airline) internal view returns (bool) {
        return ( airlines[_airline].status == AirlineState.Init);
    }
    
    // App.modifier requireRegisteredFlight() , App.registerAirline()
    function flightRegistered(bytes32 _flightKey) external view returns (bool) {
        return (flights[_flightKey].isRegistered);
    }

    // ****
    function getpassengerBalance() 
        requireAuthorizedCaller
        external
        view
        returns (uint256)                
    {
        return passengerBalances[tx.origin];
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(
        address _airline,
        string _name,
        address _caller,
        bool _registered   
    )
        requireAuthorizedCaller
        external                         
    {
        Airline storage airline = airlines[_airline];
        // First Interaction with Contract
        if (airlineFirstAction(_airline)) {
            airline.status = AirlineState.Application;
            airline.name = _name;
            airline.voteCount = 0;
        }
        
        // Consensus requirement
        if (_registered) {

            airline.status = AirlineState.Registered;
            airline.voters[_caller] = true;
            airline.voteCount = airline.voteCount.add(1);
            regAirlines = regAirlines.add(1);
            
            emit AirlineRegistered(_airline, regAirlines);

        } else {

            airline.voters[_caller] = true;
            airline.voteCount = airline.voteCount.add(1);
            
            emit ApprovalVoting(_airline, airline.voteCount, regAirlines);
            
        }
    }

    function registerFlight(
       address _airline, 
       uint256 _departure,
       string _flightCode,
       bytes32 _flightKey
    )
        requireAuthorizedCaller
        external
    {
        // Add registered flight
        flights[_flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            departure: _departure,
            lastUpdate: now,      
            airline: _airline,
            flightCode: _flightCode
        });

        registeredFlights.push(_flightKey);
        emit FlightRegistered (_flightKey);

    }

    function updateFlightStatus(bytes32 _flightKey, uint8 _statusCode)
                                requireIsOperational
                                requireAuthorizedCaller
                                external
    {
        flights[_flightKey].statusCode = _statusCode;
        emit FlightStatusProcessed(authorizedCallers[msg.sender], flights[_flightKey].flightCode, _statusCode);
    }

    // ****
    /* function getFlightStatus(bytes32 _flightKey)
        requireAuthorizedCaller
        external
        view
        returns(uint8)
    {
        return registeredFlights.length;
    } */


    // ****
    function getRegisteredFlightsCount()
        external
        view
        returns(uint256)
    {
        return registeredFlights.length;
    }

    // ****
    function getRegisteredFlight(uint256 _index)
        external
        view
        returns(
            uint256 index,
            bool isRegistered,
            uint8 statusCode,
            uint256 departure,
            address airline,
            string flightCode
        )
    {
        Flight storage flight = flights[registeredFlights[_index]];

        index = _index;
        isRegistered = flight.isRegistered;
        statusCode = flight.statusCode;
        departure = flight.departure;
        airline = flight.airline;
        flightCode = flight.flightCode;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyInsurance (address _airline, string _flightCode, uint256 _departure)
        requireIsOperational
        external
        payable
    {
        bytes32 flightKey = getFlightKey(_airline, _flightCode, _departure);
        require(
            msg.value <= MAX_INSURANCE_AMOUNT,
            "Maximum allowed insurance is 1 ether"
        );
        require(
            insurances[msg.sender][flightKey].status == InsuranceState.Init,
            "Insurance Policy already exists"
        );
        require(flights[flightKey].isRegistered, "Flight is not registered");

        // SafeMath converted 1.5x payout
        uint256 insurancePayout = msg.value.add(msg.value.div(2));
        
        insurances[msg.sender][flightKey] = Insurance({
            status: InsuranceState.Active,
            insuranceAmount: msg.value,
            insurancePayout: insurancePayout
        });
        emit InsurancePurchased(msg.sender, _flightCode);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees (
        address _airline,
        string _flightCode,
        uint256 _departure
    )
        requireIsOperational
        external
    {
        bytes32 flightKey = getFlightKey(_airline, _flightCode, _departure);
        require(
            insurances[msg.sender][flightKey].status == InsuranceState.Payable,
            "Insurance payout not due"
        );

        insurances[msg.sender][flightKey].status = InsuranceState.Received;
        uint256 payout = insurances[msg.sender][flightKey].insurancePayout;
        passengerBalances[msg.sender] = payout;
        emit PayoutToInsuree(msg.sender, _flightCode);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() requireIsOperational external {
        uint256 payout = passengerBalances[msg.sender];
        require(payout > 0, "There is no Balance available for payout");

        passengerBalances[msg.sender] = 0;
        msg.sender.transfer(payout);
        emit InsureePayout(msg.sender);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many 
    *      delayed flights resulting in insurance payouts, the contract should
    *      be self-sustaining
    *
    */   
    function fund(address _airline) requireIsOperational public payable {
        require(
            airlines[_airline].status == AirlineState.Registered,
            "Airline Status not correct"
        );
        require(msg.value >= 10 ether, "Sended Value is less than 10 Ether");

        airlines[_airline].status = AirlineState.Funded;
        authAirlines = authAirlines.add(1);
        emit AirlineFunded(_airline);
    }

    function getFlightKey(
        address _airline,
        string _flight,
        uint256 _timestamp
    )
        pure
        internal
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, _flight, _timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
            fund(msg.sender);
    }

}

