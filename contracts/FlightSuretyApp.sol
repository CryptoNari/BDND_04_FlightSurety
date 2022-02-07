pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256;

    /**************************************************************************/
    /*                            DATA VARIABLES                              */
    /**************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    
    FlightSuretyData dataContract;

 
    /**************************************************************************/
    /*                           FUNCTION MODIFIERS                           */
    /**************************************************************************/

    modifier requireIsOperational() {
        require(isOperational(), "Contract is currently not operational");  
        _;
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

     modifier onlyFundedAirline(address _airline) {
        require(
            dataContract.isFundedAirline(_airline),
            "Airline is not funded"
        );
        _;
    }

    /**************************************************************************/
    /*                             CONSTRUCTOR                                */
    /**************************************************************************/

    constructor(address _dataContractAddress) public {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataContractAddress);
    }

    /**************************************************************************/
    /*                          UTILITY FUNCTIONS                             */
    /**************************************************************************/

    function isOperational() public view returns (bool) {
        return dataContract.isOperational();
    }

    function setOperatingStatus(bool mode) requireContractOwner external {
        dataContract.setOperatingStatus(mode);
    }

    /**************************************************************************/
    /*                       SMART CONTRACT FUNCTIONS                         */
    /**************************************************************************/
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline(address _airline, string _name)
        requireIsOperational
        onlyFundedAirline(msg.sender)
        external
    {
        require(
            !dataContract.isAirline(_airline), 
            "Airline already registered"
        );
        require(
            !dataContract.doubleVoteCheck(_airline, msg.sender),
            "Caller already Voted"
        );
    
        // Multi-party consensus from fifth registration
        uint256 multiplier = 1000; // used multiplier for higher accuracy
        uint256 regAirlines = dataContract.countRegisteredAirlines();
        uint256 currentVotes = dataContract.countCurrentVotes(_airline);
        uint256 currentVotesMult = (currentVotes.add(1)).mul(multiplier);
        uint256 votesRequiredMult = regAirlines.mul(multiplier.div(2));
        bool registered = true;
        
        // check if consensus required and votes are sufficient
        if (regAirlines > 3 && currentVotesMult < votesRequiredMult) {
            registered = false;
        }

        // Transmit to Data Contract
        dataContract.registerAirline(
            _airline,
            _name,
            msg.sender,
            registered
        );
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(uint256 _departure, string _name)
        requireIsOperational
        onlyFundedAirline(msg.sender)
        external
    {
        // check if Flight is already registered
        bytes32 flightKey = getFlightKey(msg.sender, _name, _departure);
        require(!dataContract.flightRegistered(flightKey));
        
        dataContract.registerFlight(
            msg.sender,
            _departure, 
            _name,
            flightKey
        );
    }

    // ****
    function getFlightInfo(uint256 _index)
        view
        external
        returns (
            uint256 index,
            bool isRegistered,
            uint8 statusCode,
            uint256 departure,
            address airline,
            string flightode
        )
    {
        return dataContract.getRegisteredFlight(_index);
    }

    // ****
    function getPassengerBalance() view external returns (uint256) {
        return dataContract.getpassengerBalance();
    }


   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(
        address _airline,
        string _flight,
        uint256 _timestamp,
        uint8 _statusCode
    )
        requireIsOperational
        internal
    {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        dataContract.updateFlightStatus(flightKey, _statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address _airline,
        string _flight,
        uint256 _timestamp                            
    )
        requireIsOperational
        public
    {
        uint8 index = getRandomIndex(msg.sender);
        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(
                                                index, 
                                                _airline, 
                                                _flight, 
                                                _timestamp
                                                ));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, _airline, _flight, _timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 6;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a respons
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 _index,
        address _airline,
        string _flight,
        uint256 _timestamp,
        uint8 _statusCode
    )
        public
    {   
        uint8 index0 = oracles[msg.sender].indexes[0];
        uint8 index1 = oracles[msg.sender].indexes[1];
        uint8 index2 = oracles[msg.sender].indexes[2];

        require(
            ((index0 == _index) || (index1 == _index) || (index2 == _index)),
            "Index does not match oracle request"
        );


        bytes32 key = keccak256(abi.encodePacked(
                                                _index,
                                                _airline,
                                                _flight,
                                                _timestamp
                                                )); 
        require(
            oracleResponses[key].isOpen, 
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[_statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(_airline, _flight, _timestamp, _statusCode);
        if (oracleResponses[key].responses[_statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(_airline, _flight, _timestamp, _statusCode);
            
            // Handle flight status as appropriate
            processFlightStatus(_airline, _flight, _timestamp, _statusCode);
        }
    }


    function getFlightKey(address _airline, string _flight, uint256 _timestamp)
        pure
        internal
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, _flight, _timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address _account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(_account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(_account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(_account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address _account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(
                                 keccak256(
                                     abi.encodePacked(
                                         blockhash(block.number - nonce++),
                                         _account
                                     )
                                 )
                             ) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

