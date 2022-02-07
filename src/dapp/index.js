
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


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
        
        // get Registered Flights
        /* let flightCount = contract.getRegisteredFlightsCount();
        console.log(`ID:${flightCount}`);
        for(let i = 0 ; i < 3 ; i ++ ) {
            contract.getRegisteredFlight(i, (error, result) => {
                showFlights([ { flightCode: result.flightCode, error: error} ]);
            })
        }; */
        

        // User-submitted transaction
        DOM.elid('load-flights').addEventListener('click', () => {
            contract.getRegisteredFlightsCount((error, result) => {
                console.log(error,result);
                for(let i = 0 ; i < result ; i ++ ) {
                    contract.getRegisteredFlight(i, (error, result) => {
                        showFlights(result);
                    });
                };
            });
        })

        DOM.elid("buy-insurance").addEventListener("click", async () => {
            let payload = {
                airline: DOM.elid("buy-airline").value,
                flightCode: DOM.elid("buy-flight-code").value,
                departure: DOM.elid("buy-departure").value,
                insuree: DOM.elid("insurance-buyer").value,
                value: DOM.elid("insurance-paid").value
            };

            let err, result, label;
            try {
                await contract.buyInsurance(payload);
            } catch (e) {
                err = e;
                console.log(e);
            } finally {
    
            }
        });

        

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
    
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

function showFlights(results) {
    let displayDiv = DOM.elid("table-body");
    let trow = DOM.tr();
    trow.appendChild(DOM.th({scope: 'row'}, results.index));
    trow.appendChild(DOM.td(results.flightCode));
    trow.appendChild(DOM.td(results.airline));
    trow.appendChild(DOM.td(results.statusCode));
    displayDiv.append(trow);
    
    /* section.appendChild(DOM.th({scope: 'row'}, results.index));
    section.appendChild(DOM.td(results.airline));
    section.appendChild(DOM.td(results.flightCode));
    section.appendChild(DOM.td(results.statusCode));
    displayDiv.append(section) */;
    
}








