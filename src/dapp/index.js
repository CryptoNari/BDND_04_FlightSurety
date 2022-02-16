
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';

let insuranceStates = ["Init","Active","Payable","Closed","Received"];
let flightStates = [ "UNKNOWN", "ON_TIME", "LATE_AIRLINE", "LATE_WEATHER","LATE_TECHNICAL","LATE_OTHER"];


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {


        // Navigation-Bar Setup
        let navigation = ["nav-contract", "nav-airlines", "nav-flights", "nav-insurance"].map(navItem=>{
            return DOM.elid(navItem);
        });

        let containers = ["contract-forms", "airlines-forms", "flights-forms", "insurance-forms"].map(container=>{
            return DOM.elid(container);
        });

        navigation.forEach((item, index, array)=>{
            item.addEventListener("click", ()=>{
                array.forEach((navItem, idx, arr)=>{
                    navItem.classList.remove("active");
                    containers[idx].style.display = "none";
                });
                item.classList.add("active");
                containers[index].style.display = "block";
            })
        })


        DOM.elid('load-flights').addEventListener('click', () => {
            getFlights();
        })

        DOM.elid('payout-balance').addEventListener('click', () => {
            let caller = DOM.elid("insuree").value;
            contract.payoutInsurance(caller);
        })


        DOM.elid('get-acc-balance').addEventListener('click', () => {
            let caller = DOM.elid("insuree").value;
            contract.getAccBalance(caller, result => {
                console.log(result);
                let balance = DOM.elid("acc-balance");
                balance.readOnly = false;
                balance.value = contract.web3.utils.fromWei(result);
                balance.readOnly = true;
            })
        })

        DOM.elid('get-ins-balance').addEventListener('click', () => {
            let caller = DOM.elid("insuree").value;
            contract.getBalance(caller, (error, result) => {
                console.log(error,result);
                let balance = DOM.elid("ins-balance");
                balance.readOnly = false;
                balance.value = contract.web3.utils.fromWei(result);
                balance.readOnly = true;
            })
        })

        DOM.elid('show-insurances').addEventListener('click', () => {
            getInsurances();
        })

        DOM.elid("buy-insurance").addEventListener("click", async () => {
            let flight = DOM.elid("flight").value;
            let account = DOM.elid("insuree").value;
            let i;
            
            let payload = {
                flightCode: flight,
                insuree: account,
                value: DOM.elid("value").value
            };
            console.log(payload);

            try {
                contract.buyInsurance(payload);
            } catch (e) {
                let err = e;
                console.log(e);
            } finally {
                // getInsurances();
            }
            
        });

        

        // Read transaction
        contract.isOperational((error, result) => {
            // console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        contract.fundAirline(contract.airlines[0], (error, result) => {
            console.log(error,result);
           
        });


        function getFlights() {
            removeFlights();
            contract.getRegisteredFlightsCount((error, result) => {
                // console.log(error,result);
                for(let i = 0 ; i < result ; i ++ ) {
                    contract.getRegisteredFlight(i, (error, result) => {
                        showFlights(result);
                    });
                };
            });
        }

        function getInsurances() {
            removeInsurances();
            let flight = DOM.elid("flight").value;
            let caller = DOM.elid("insuree").value;
            // console.log(`INDEX:inputs flight:${flight}, caller: ${caller}`)
                // GET FLIGHT CODE
            contract.getInsurance(flight, caller, (error, result) => {
                //console.log(`INDEX:result: ${result.status}`)
                showInsurances(result);
            });
                
            
        }

        function showInsurances(results) {
            let displayDiv = DOM.elid("insurance-table-body");
            let trow = DOM.tr();
            
            trow.appendChild(DOM.td(insuranceStates[results.status]));
            trow.appendChild(DOM.td(results.flightCode));
            trow.appendChild(DOM.td(flightStates[results.flightStatus/10]));
            if (results.status !== '2'){

                let button = DOM.button({id:"submit-oracle", className:"btn btn-primary"}, "Get Flight Status");
                button.addEventListener('click', () => {
                    let flight = DOM.elid("flight").value;
                    // Write transaction
                    contract.fetchFlightStatus(flight, (error, result) => {
                        display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
                        
                        // getInsurances();
                    });
                });
                trow.appendChild(DOM.td().appendChild(button))

            } else if (results.status === '2') { //payable

                let button = DOM.button({id:"submit-oracle", className:"btn btn-primary"}, "Claim Insurance");
                button.addEventListener('click', () => {
                    let flight = DOM.elid("flight").value;
                    let caller = DOM.elid("insuree").value;
                    // Write transaction
                    //console.log(`INDEX:credit flight:${flight}, caller: ${caller}`)
                    contract.creditInsurees(flight, caller, (error, result) => {
                        //console.log(`INDEX:credit flight:${flight}, caller: ${caller}, result: ${result}`);
                    });
                });
                trow.appendChild(DOM.td().appendChild(button))
            } 
            
            
            
            displayDiv.append(trow);    
        } 
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section({className: 'text-dark'},);
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col field'}, result.label));
        row.appendChild(DOM.div({className: 'col field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);
}

function removeFlights() {
    let table = DOM.elid("flights-table");
    let tableBody = DOM.tbody({id: 'table-body'});
    DOM.elid("table-body").remove();
    table.append(tableBody);
}

function removeInsurances() {
    let table = DOM.elid("insurance-table");
    let tableBody = DOM.tbody({id: 'insurance-table-body'});
    DOM.elid("insurance-table-body").remove();
    table.append(tableBody);
}

function showFlights(results) {
    let displayDiv = DOM.elid("table-body");
    let trow = DOM.tr();
    trow.appendChild(DOM.th({scope: 'row'}, results.index));
    trow.appendChild(DOM.td(results.flightCode));
    trow.appendChild(DOM.td(results.airline));
    trow.appendChild(DOM.td(results.departure));
    trow.appendChild(DOM.td(results.statusCode));
    displayDiv.append(trow);    
}