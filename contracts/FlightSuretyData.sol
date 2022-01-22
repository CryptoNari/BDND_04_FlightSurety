pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    address private firstAirline = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;                                      // Account used to deploy contract
    bool private operational = true;                                   // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCallers;
    uint256 authAirlines = 0; // Airlines authorized for consensus voting
    uint256 regAirlines = 0; // Airlines registered 

    enum AirlineState {
        Applied,
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

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineApplied (address airlineAddresse, uint votes, uint regAirlines);
    event ApprovalVoting (address airlineAddresse, uint votes, uint regAirlines);
    event AirlineRegistered (address airlineAddresse, uint regAirlines);
    event AirlineFunded (address airlineAddresse);
    event ApprovalVoting (address airlineAddresse);



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
        regAirlines +=1;
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
        authorizedCallers[authCaller] = status ;
    }



    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function countRegisteredAirlines
                    (

                    )
                    external
                    view
                    returns(uint)
    {
        return regAirlines;
    }

    function inApplyRegisterState              
                    (
                        address airline
                    )
                    external
                    view
                    returns(bool)
    {
        AirlineState status = airlines[airline].status;
        if ( status == AirlineState.Applied) {
            return true;
        } else {
            return false;
        }
        
    }
    
    function isAirline             
                    (
                        address airline
                    )
                    external
                    view
                    returns(bool)
    {
        AirlineState status = airlines[airline].status;
        if ( status == AirlineState.Registered || status == AirlineState.Funded) {
            return true;
        } else {
            return false;
        }
        
    }

    function isFundedAirline
                    
                    (
                        address airline
                    )
                    external
                    view
                    returns(bool)
    {
        AirlineState status = airlines[airline].status;
        if (status == AirlineState.Funded) {
            return true;
        } else {
            return false;
        }
        
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address airline,
                                string name,
                                address caller   
                            )
                            requireAuthorizedCaller
                            external
                            
    {
        // Multi-party consensus from fifth registration
        if (regAirlines < 4) {
            airlines[airline] = Airline({
                status: AirlineState.Registered,
                name: name,
                voteCount: 0
            });
            regAirlines += 1;
            emit AirlineRegistered(airline, regAirlines);
        } else {
            airlines[airline] = Airline({
                status: AirlineState.Applied,
                name: name,
                voteCount: 1
            });
            airlines[airline].voters[caller] = true;
            emit AirlineApplied(airline, 1, regAirlines);
        }  
    }
 function approveAirlineConsensus
                            (
                                address airline,
                                address caller
                            )
                            requireAuthorizedCaller
                            external
    {   
        require(airlines[airline].status == AirlineState.Applied, "This Airlane is not applying for Registration");
        require(!airlines[airline].voters[caller], "AuthAirline has already Voted for Approval");
        
        airlines[airline].voters[caller] = true;
        airlines[airline].voteCount += 1;
        
        uint multiplier = 100;
        uint votes = airlines[airline].voteCount * multiplier;
        uint votesRequired = regAirlines * multiplier / 2;

        if  (votes >= votesRequired) {
            airlines[airline].status = AirlineState.Registered;
            regAirlines += 1;
            emit AirlineRegistered(airline, regAirlines);
        } else {
            votes = votes / multiplier;
            emit ApprovalVoting(airline, votes, regAirlines);
        }
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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
                            public
                            payable
    {
        require(msg.value >= 10 ether);
        airlines[airline].status = AirlineState.Funded;
        authAirlines += 1;
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
   /*  function() 
                            external 
                            payable 
        {
            fund();
        } */


}

