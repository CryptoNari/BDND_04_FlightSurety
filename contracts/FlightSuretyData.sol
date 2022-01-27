pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    address private firstAirline = 0xf17f52151EbEF6C7334FAD080c5704D77216b732; 
    bool private operational = true;  // Blocks all state changes throughout the contract if false

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

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 departure;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] registeredFlights;

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
    


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineinApplication (address airlineAddresse, uint votes, uint regAirlines);
    event ApprovalVoting (address airlineAddresse, uint votes, uint regAirlines);
    event AirlineRegistered (address airlineAddresse, uint regAirlines);
    event AirlineFunded (address airlineAddresse);
    event FlightRegistered(bytes32 flightKey);
    event InsurancePurchased(address buyer,string flight, uint256 amount);
    event Bugfix (uint256 reg);
    



    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        airlines[firstAirline] = Airline({
            status: AirlineState.Registered,
            name: "FirstAirline",
            voteCount: 0
        });
        regAirlines = regAirlines.add(1);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }
    /**
    * @dev Modifier that requires the an authorised "ContractCaller" account to be the function caller
    */
    modifier requireAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender], "Caller is not authorised");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }


    /**
    * @dev Sets authorized ContractCaller Addresses
    *
    */
    function authorizeCaller 
                            (
                                address authCaller,
                                bool status
                            ) 
                            external
                            requireContractOwner
    {
        authorizedCallers[authCaller] = status;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    // App.modifier onlyFundedAirline() 
    function isFundedAirline(address airline)
                    external
                    view
                    returns(bool)
    {
        return (airlines[airline].status == AirlineState.Funded);       
    }
    
    // App.registerAirline()
    function isAirline(address airline)
                    external
                    view
                    returns(bool)
    {
        AirlineState status = airlines[airline].status;
        return ( status == AirlineState.Registered || status == AirlineState.Funded);
    }

    // App.registerAirline()
    function countRegisteredAirlines()
                    external
                    view
                    returns(uint)
    {
        return regAirlines;
    }

    /// App.registerAirline()
    function countCurrentVotes(address airline)
                    external
                    view
                    returns(uint)
    {
        return airlines[airline].voteCount;
    }

    // App.registerAirline()
    function doubleVoteCheck(address airline, address caller)
                    external
                    view
                    returns(bool)
    {
        return airlines[airline].voters[caller];
    }

    // Data.registerAirline()
    function airlineFirstAction(address airline)
                    internal
                    view
                    returns(bool)
    {
        return ( airlines[airline].status == AirlineState.Init);
    }
    
    // App.modifier requireRegisteredFlight() , App.registerAirline()
    function flightRegistered(bytes32 flightKey)
                    external
                    view
                    returns(bool)
    {
        return (flights[flightKey].isRegistered);
    }

    // ****
    function getpassengerBalance()
                    requireAuthorizedCaller
                    external
                    view
                    returns(uint256)
                    
    {
        return passengerBalances[tx.origin];
    }
    

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(
                                address airline,
                                string name,
                                address caller,
                                bool registered   
                            )
                            requireIsOperational
                            requireAuthorizedCaller
                            external
                            returns(bool success, uint256 _votes, uint256 _regAirlines)                            
    {
        // First Interaction with Contract
        if (airlineFirstAction(airline)) {

            airlines[airline] = Airline({
                status: AirlineState.Application,
                name: name,
                voteCount: 0
            });
        }
        
        // Consensus requirement
        if (registered) {

            airlines[airline].status = AirlineState.Registered;
            airlines[airline].voters[caller] = true;
            airlines[airline].voteCount = airlines[airline].voteCount.add(1);
            regAirlines = regAirlines.add(1);
            
            
            emit AirlineRegistered(airline, regAirlines);
            return (registered, 1, regAirlines);

        } else {

            airlines[airline].voters[caller] = true;
            airlines[airline].voteCount = airlines[airline].voteCount.add(1);
            _votes = airlines[airline].voteCount;

            emit ApprovalVoting(airline, _votes, regAirlines);
            return (registered, _votes, regAirlines);
            
        }
    }


    function registerFlight(
                               address airline, 
                               uint256 _departure,
                               string name,
                               bytes32 flightKey
                            )
                            requireIsOperational
                            requireAuthorizedCaller
                            external
                            returns(bool success, bytes32 _flightKey)
    {
        // Add registered flight
        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            departure: _departure,      
            airline: airline
        });

        registeredFlights.push(flightKey);
        emit FlightRegistered (flightKey);
        
        return (true, flightKey);
    }

    // ****
    function getRegisteredFlightsCount
                                (
                                )
                                requireIsOperational
                                requireAuthorizedCaller
                                external
                                view
                                returns(uint256)
    {
        return registeredFlights.length;
    }
    // ****
    function getRegisteredFlight
                                (
                                    uint256 index
                                )
                                requireIsOperational
                                requireAuthorizedCaller
                                external
                                view
                                returns(bool _isRegistered, uint8 _statusCode, uint256 _departure, address _airline)
    {
        _isRegistered = flights[registeredFlights[index]].isRegistered;
        _statusCode = flights[registeredFlights[index]].statusCode;
        _departure = flights[registeredFlights[index]].departure;
        _airline = flights[registeredFlights[index]].airline;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyInsurance
                            (  
                                address airline,
                                string flight,
                                uint256 departure
                            )
                            requireIsOperational
                            external
                            payable
    {
        bytes32 flightKey = getFlightKey(airline, flight, departure);
        require(msg.value <= MAX_INSURANCE_AMOUNT, "Maximum allowed insurance is 1 ether");
        require(insurances[msg.sender][flightKey].status == InsuranceState.Init, "Insurance Policy already exists");
        require(flights[flightKey].isRegistered, "Flight is not registered");

        uint256 insurancePayout = msg.value.add(msg.value.div(2)); // SafeMath converted 1.5x payout
        
        insurances[msg.sender][flightKey] = Insurance({
            status: InsuranceState.Active,
            insuranceAmount: msg.value,
            insurancePayout: insurancePayout
        });
        emit InsurancePurchased(msg.sender, flight, msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                            (
                                address airline,
                                string flight,
                                uint256 departure
                            )
                            requireIsOperational
                            external
    {
        bytes32 flightKey = getFlightKey(airline, flight, departure);
        require(flights[flightKey].statusCode == 20, "Insurance does not exist"); // double test
        require(insurances[msg.sender][flightKey].status == InsuranceState.Payable, "Insurance payout not due");
        // require(true, "");

        insurances[msg.sender][flightKey].status = InsuranceState.Received;
        passengerBalances[msg.sender] = insurances[msg.sender][flightKey].insurancePayout;
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            requireIsOperational
                            external
    {
        require(true, "");
        uint256 payout = passengerBalances[msg.sender];
        passengerBalances[msg.sender] = 0;
        msg.sender.transfer(payout);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            ( 
                                address airline  
                            )
                            requireIsOperational
                            public
                            payable
    {
        //require(airlines[airline].status == AirlineState.Registered, "Airline Status not correct");
        require(msg.value >= 10 ether, "Sended Value is less than 10 Ether");
        airlines[airline].status = AirlineState.Funded;
        authAirlines = authAirlines.add(1);
        emit AirlineFunded(airline);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable
        {
            fund(msg.sender);
        }


}

