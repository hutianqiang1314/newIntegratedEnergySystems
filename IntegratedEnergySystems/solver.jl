using JuMP
using Ipopt

# Function to solve the model
function solve_model(model)
    # Set solver options for better convergence
    set_optimizer_attribute(model, "max_iter", 100000)
    set_optimizer_attribute(model, "tol", 1e-6)
    # mute the solver output
    set_optimizer_attribute(model, "print_level", 0)
    
    # Solve the model
    optimize!(model)
    
    # Check if the model was solved successfully
    if termination_status(model) == MOI.OPTIMAL || termination_status(model) == MOI.LOCALLY_SOLVED
        println("Model solved successfully")
        println("Objective value: ", objective_value(model))
        
        # Extract and return the results
        return extract_results(model)
    else
        println("Model could not be solved")
        println("Termination status: ", termination_status(model))
        return nothing  # Return nothing instead of false
    end
end

# Function to extract results from the solved model
function extract_results(model)
    results = Dict()
    
    # Add success flag
    results["success"] = true
    
    # Energy sources
    results["P_grid"] = value.(model[:P_grid])
    results["P_solar"] = value.(model[:P_solar])
    results["P_wind"] = value.(model[:P_wind])
    results["P_CHP"] = value.(model[:P_CHP])
    results["Q_CHP"] = value.(model[:Q_CHP])
    results["F_CHP"] = value.(model[:F_CHP])
    results["F_fuel"] = value.(model[:F_fuel])
    results["P_fuelcell"] = value.(model[:P_fuelcell])
    results["F_E2F"] = value.(model[:F_E2F])  # Add missing synthetic fuel variable
    
    # Energy conversion - UPDATED: Split electrolysis pathways
    results["P_electrolysis_H2"] = value.(model[:P_electrolysis_H2])
    results["P_electrolysis_fuel"] = value.(model[:P_electrolysis_fuel])
    results["H_electrolysis"] = value.(model[:H_electrolysis])
    results["H_fuelcell"] = value.(model[:H_fuelcell])
    results["P_HP"] = value.(model[:P_HP])
    results["Q_HP"] = value.(model[:Q_HP])
    
    # Storage
    results["E_storage"] = value.(model[:E_storage])
    results["Q_storage"] = value.(model[:Q_storage])
    results["H_storage"] = value.(model[:H_storage])
    results["P_storage_charge"] = value.(model[:P_storage_charge])
    results["P_storage_discharge"] = value.(model[:P_storage_discharge])
    results["Q_storage_charge"] = value.(model[:Q_storage_charge])
    results["Q_storage_discharge"] = value.(model[:Q_storage_discharge])
    results["H_storage_charge"] = value.(model[:H_storage_charge])
    results["H_storage_discharge"] = value.(model[:H_storage_discharge])
    
    # Demand
    results["P_industry_elec"] = value.(model[:P_industry_elec])
    results["Q_industry_th"] = value.(model[:Q_industry_th])
    results["H_industry"] = value.(model[:H_industry])
    results["F_industry"] = value.(model[:F_industry])
    results["P_buildings_elec"] = value.(model[:P_buildings_elec])
    results["Q_buildings_th"] = value.(model[:Q_buildings_th])
    
    # Transportation
    results["D_ICV"] = value.(model[:D_ICV])
    results["D_EV"] = value.(model[:D_EV])
    results["D_HV"] = value.(model[:D_HV])
    
    # Vehicle energy consumption and state of charge
    results["F_ICV_refuel"] = value.(model[:F_ICV_refuel])
    results["SOC_ICV"] = value.(model[:SOC_ICV])
    
    results["H_HV_refuel"] = value.(model[:H_HV_refuel])
    results["SOC_HV"] = value.(model[:SOC_HV])
    
    # V2G
    results["SOC_EV"] = value.(model[:SOC_EV])
    results["P_EV_charge"] = value.(model[:P_EV_charge])
    results["P_EV_V2G"] = value.(model[:P_EV_V2G])
    
    # Carbon capture
    results["CO2_captured"] = value.(model[:CO2_captured])
    
    # Emissions
    results["Emissions_total"] = value.(model[:Emissions_total])
    
    # Green certificates
    results["Cert_purchase"] = value.(model[:Cert_purchase])
    
    # CCUS energy consumption
    results["P_CCUS"] = value.(model[:P_CCUS])
    # Add total electrolysis power for backward compatibility
    # This is the sum of both electrolysis pathways
    T = length(results["P_electrolysis_H2"])
    results["P_electrolysis"] = results["P_electrolysis_H2"] + results["P_electrolysis_fuel"]
    
    return results
end
