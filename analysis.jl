using Statistics
using Printf  # Add this import for sprintf functionality

# Helper function to validate results and parameters
function validate_analysis_inputs(results, T, params)
    # Check if results is a valid dictionary
    if !isa(results, Dict) || isempty(results)
        return Dict(
            "error" => "No valid results available for analysis",
            "success" => false
        )
    end
    
    # Check if params is a dictionary or not
    if !isa(params, Dict)
        params = Dict(
            "gamma_elec" => 0.5,
            "gamma_fuel" => 1.0,
            "eta_power_to_fuel" => 0.5,
            "eta_heatpump" => 3.0,
            "eta_electrolysis" => 0.7
        )
    end
    
    return Dict("success" => true, "params" => params)
end

# Helper function to safely sum vector values
function safe_sum(results, key, T)
    if haskey(results, key) && isa(results[key], Vector)
        if length(results[key]) >= T
            return sum(results[key][1:T])
        else
            return sum(results[key])
        end
    end
    return 0.0
end

# Helper function to safely average vector values
function safe_average(results, key, T)
    if haskey(results, key) && isa(results[key], Vector)
        vector_length = min(length(results[key]), T)
        if vector_length > 0
            return sum(results[key][1:vector_length]) / vector_length
        end
    end
    return 0.0
end

# Helper function to extract gamma values safely
function extract_gamma_values(results, params, T)
    gamma_elec = if haskey(params, "gamma_elec")
        params["gamma_elec"]
    elseif haskey(results, "gamma_elec")
        results["gamma_elec"]
    else
        0.5
    end
    
    gamma_fuel = if haskey(params, "gamma_fuel")
        params["gamma_fuel"]
    elseif haskey(results, "gamma_fuel")
        results["gamma_fuel"]
    else
        1.0
    end

    # Ensure gamma_elec is properly sized for the simulation period
    if isa(gamma_elec, Number)
        gamma_elec = fill(gamma_elec, T)
    elseif length(gamma_elec) < T
        gamma_elec = [gamma_elec; fill(gamma_elec[end], T - length(gamma_elec))]
    elseif length(gamma_elec) > T
        gamma_elec = gamma_elec[1:T]
    end
    
    return gamma_elec, gamma_fuel
end

# Helper function to calculate basic energy totals
function calculate_energy_totals(results, T)
    return Dict(
        "total_grid" => safe_sum(results, "P_grid", T),
        "total_solar" => safe_sum(results, "P_solar", T),
        "total_wind" => safe_sum(results, "P_wind", T),
        "total_CHP_elec" => safe_sum(results, "P_CHP", T),
        "total_CHP_heat" => safe_sum(results, "Q_CHP", T),
        "total_fuelcell" => safe_sum(results, "P_fuelcell", T),
        "total_fuel_external" => safe_sum(results, "F_fuel", T),
        "total_fuel_CHP" => safe_sum(results, "F_CHP", T),
        "total_fuel_industry" => safe_sum(results, "F_industry", T),
        "total_fuel_ICV" => safe_sum(results, "F_ICV_refuel", T),
        "total_hydrogen_electrolysis" => safe_sum(results, "H_electrolysis", T),
        "total_hydrogen_industry" => safe_sum(results, "H_industry", T),
        "total_hydrogen_vehicles" => safe_sum(results, "H_HV_refuel", T),
        "total_hydrogen_fuelcell" => safe_sum(results, "H_fuelcell", T),
        "total_CCU_energy" => safe_sum(results, "P_CCU", T),
        "total_ICV_distance" => safe_sum(results, "D_ICV", T),
        "total_EV_distance" => safe_sum(results, "D_EV", T),
        "total_HV_distance" => safe_sum(results, "D_HV", T),
        "total_V2G" => safe_sum(results, "P_EV_V2G", T),
        "total_ICV_refuel" => safe_sum(results, "F_ICV_refuel", T),
        "total_EV_charge" => safe_sum(results, "P_EV_charge", T),
        "total_HV_refuel" => safe_sum(results, "H_HV_refuel", T)
    )
end

# Helper function to calculate emissions
function calculate_emissions(results, params, gamma_elec, gamma_fuel, T)
    # Grid emissions
    grid_emissions = 0.0
    if haskey(results, "P_grid") && length(results["P_grid"]) >= T
        grid_emissions = sum(gamma_elec[1:T] .* results["P_grid"][1:T])
    end
    
    # Fuel emissions
    fuel_emissions = gamma_fuel * safe_sum(results, "F_fuel", T)
    
    # Total emissions before capture
    total_emissions_before_capture = grid_emissions + fuel_emissions
    
    # Carbon captured and certificates
    total_captured = safe_sum(results, "CO2_captured", T)
    total_certificates = safe_sum(results, "Cert_purchase", T)
    
    # Net emissions
    net_emissions = total_emissions_before_capture - total_captured - total_certificates
    
    return Dict(
        "grid_emissions" => grid_emissions,
        "fuel_emissions" => fuel_emissions,
        "total_emissions_before_capture" => total_emissions_before_capture,
        "total_captured" => total_captured,
        "total_certificates" => total_certificates,
        "net_emissions" => net_emissions
    )
end

# Function to analyze results
function analyze_results(results, T, params)
    # Validate inputs
    validation = validate_analysis_inputs(results, T, params)
    if !validation["success"]
        return validation
    end
    params = validation["params"]
    
    # Extract gamma values
    gamma_elec, gamma_fuel = extract_gamma_values(results, params, T)
    
    # Calculate basic energy totals
    energy_totals = calculate_energy_totals(results, T)
    
    # Calculate emissions
    emissions = calculate_emissions(results, params, gamma_elec, gamma_fuel, T)
    
    # Calculate renewable percentage
    total_electricity_generation = energy_totals["total_grid"] + energy_totals["total_solar"] + 
                                  energy_totals["total_wind"] + energy_totals["total_CHP_elec"] + 
                                  energy_totals["total_fuelcell"]
    renewable_percentage = total_electricity_generation > 0 ? 
                          (energy_totals["total_solar"] + energy_totals["total_wind"]) / total_electricity_generation * 100 : 0.0
    
    # Calculate storage utilization averages
    storage_metrics = Dict(
        "storage_charge_avg" => safe_sum(results, "P_storage_charge", T) / T,
        "storage_discharge_avg" => safe_sum(results, "P_storage_discharge", T) / T,
        "thermal_storage_charge_avg" => safe_sum(results, "Q_storage_charge", T) / T,
        "thermal_storage_discharge_avg" => safe_sum(results, "Q_storage_discharge", T) / T,
        "hydrogen_storage_charge_avg" => safe_sum(results, "H_storage_charge", T) / T,
        "hydrogen_storage_discharge_avg" => safe_sum(results, "H_storage_discharge", T) / T
    )
    
    # Calculate vehicle metrics
    total_transport_distance = energy_totals["total_ICV_distance"] + energy_totals["total_EV_distance"] + energy_totals["total_HV_distance"]
    vehicle_metrics = Dict(
        "total_transport_distance" => total_transport_distance,
        "avg_ICV_SOC" => safe_average(results, "SOC_ICV", T),
        "avg_EV_SOC" => safe_average(results, "SOC_EV", T),
        "avg_HV_SOC" => safe_average(results, "SOC_HV", T)
    )
    
    # Calculate actual system efficiencies
    efficiency_metrics = calculate_actual_efficiencies(results, params, energy_totals, T)
    
    # Combine all metrics
    metrics = merge(energy_totals, emissions, storage_metrics, vehicle_metrics, efficiency_metrics)
    metrics["renewable_percentage"] = renewable_percentage
    metrics["success"] = true
    
    # Add seasonal metrics for yearly simulations
    if T > 1000
        seasonal_metrics = calculate_seasonal_metrics(results, T)
        metrics = merge(metrics, seasonal_metrics)
    end
    
    return metrics
end

# Helper function to calculate actual system efficiencies
function calculate_actual_efficiencies(results, params, energy_totals, T)
    eta_CHP = get(params, "eta_CHP", 0.85)
    eta_heatpump = get(params, "eta_heatpump", 3.0)
    eta_electrolysis = get(params, "eta_electrolysis", 0.7)
    
    # CHP actual efficiency
    actual_CHP_efficiency = if energy_totals["total_fuel_CHP"] > 0
        (energy_totals["total_CHP_elec"] + energy_totals["total_CHP_heat"]) / energy_totals["total_fuel_CHP"]
    else
        0
    end
    
    # Heat pump performance
    total_HP_heat = safe_sum(results, "Q_HP", T)
    total_HP_electricity = safe_sum(results, "P_HP", T)
    actual_HP_COP = total_HP_electricity > 0 ? total_HP_heat / total_HP_electricity : 0
    
    # Electrolysis efficiency
    total_electrolysis_power = safe_sum(results, "P_electrolysis", T)
    actual_electrolysis_efficiency = total_electrolysis_power > 0 ? 
                                   energy_totals["total_hydrogen_electrolysis"] / total_electrolysis_power : 0
    
    return Dict(
        "actual_CHP_efficiency" => actual_CHP_efficiency,
        "actual_HP_COP" => actual_HP_COP,
        "actual_electrolysis_efficiency" => actual_electrolysis_efficiency
    )
end

# Helper function to calculate seasonal metrics for yearly simulations
function calculate_seasonal_metrics(results, T)
    # Divide the year into seasons
    winter_indices = [1:2160..., 8040:8760...]
    spring_indices = 2161:4344
    summer_indices = 4345:6552
    autumn_indices = 6553:8039
    
    function calculate_seasonal_renewable(indices)
        seasonal_solar = 0.0
        seasonal_wind = 0.0
        seasonal_total = 0.0
        
        if haskey(results, "P_solar") && haskey(results, "P_wind") && 
           haskey(results, "P_grid") && haskey(results, "P_CHP") && 
           haskey(results, "P_fuelcell")
            
            valid_indices = filter(i -> i <= length(results["P_solar"]) && 
                                        i <= length(results["P_wind"]) && 
                                        i <= length(results["P_grid"]) && 
                                        i <= length(results["P_CHP"]) && 
                                        i <= length(results["P_fuelcell"]), indices)
            
            if !isempty(valid_indices)
                seasonal_solar = sum(results["P_solar"][valid_indices])
                seasonal_wind = sum(results["P_wind"][valid_indices])
                seasonal_total = seasonal_solar + seasonal_wind + 
                                sum(results["P_grid"][valid_indices]) + 
                                sum(results["P_CHP"][valid_indices]) + 
                                sum(results["P_fuelcell"][valid_indices])
            end
        end
        
        return seasonal_total > 0 ? (seasonal_solar + seasonal_wind) / seasonal_total * 100 : 0.0
    end
    
    return Dict(
        "winter_renewable_percentage" => calculate_seasonal_renewable(winter_indices),
        "spring_renewable_percentage" => calculate_seasonal_renewable(spring_indices),
        "summer_renewable_percentage" => calculate_seasonal_renewable(summer_indices),
        "autumn_renewable_percentage" => calculate_seasonal_renewable(autumn_indices)
    )
end

# Function to check energy balance
function check_energy_balance(results, T, params)
    # Validate inputs
    validation = validate_analysis_inputs(results, T, params)
    if !validation["success"]
        return false
    end
    params = validation["params"]
    
    # Extract efficiency parameters exactly as in model
    eta_power_to_fuel = get(params, "eta_power_to_fuel", 0.5)
    eta_electrolysis = get(params, "eta_electrolysis", 0.7)
    eta_fuelcell = get(params, "eta_fuelcell", 0.5)
    eta_heatpump = get(params, "eta_heatpump", 3.0)
    eta_CHP_elec = get(params, "eta_CHP_elec", 0.4)
    eta_CHP_th = get(params, "eta_CHP_th", 0.45)
    eta_wasteheat = get(params, "eta_wasteheat", 0.1)
    eta_CH = get(params, "eta_CH", 0.95)
    eta_DC = get(params, "eta_DC", 0.95)
    eta_elec = get(params, "eta_elec", 0.999)
    eta_th = get(params, "eta_th", 0.99)
    eta_hydrogen = get(params, "eta_hydrogen", 0.999)
    eta_EV_charge = get(params, "eta_EV_charge", 0.9)
    eta_EV_discharge = get(params, "eta_EV_discharge", 0.9)
    
    # Vehicle parameters
    alpha_ICV = get(params, "alpha_ICV", 0.2)
    alpha_EV = get(params, "alpha_EV", 0.15)
    alpha_HV = get(params, "alpha_HV", 0.3)
    
    # Check electricity balance for each time step - EXACT SAME AS MODEL
    electricity_balance_error = zeros(T)
    for t in 1:T
        # Supply side - exactly as in electricity_balance constraint
        supply = safe_get(results, "P_grid", t) + safe_get(results, "P_solar", t) + safe_get(results, "P_wind", t) + 
                 safe_get(results, "P_CHP", t) + safe_get(results, "P_fuelcell", t) + 
                 safe_get(results, "P_storage_discharge", t) + safe_get(results, "P_EV_V2G", t)
        
        # Demand side - exactly as in electricity_balance constraint
        demand = safe_get(results, "P_industry_elec", t) + safe_get(results, "P_buildings_elec", t) + 
                 safe_get(results, "P_electrolysis_H2", t) + safe_get(results, "P_electrolysis_fuel", t) + 
                 safe_get(results, "P_HP", t) + safe_get(results, "P_storage_charge", t) + 
                 safe_get(results, "P_EV_charge", t) + safe_get(results, "P_CCUS", t)
        
        electricity_balance_error[t] = supply - demand
    end
    
    # Check heat balance for each time step - EXACT SAME AS MODEL
    heat_balance_error = zeros(T)
    for t in 1:T
        # Supply side - exactly as in heat_balance constraint
        supply = safe_get(results, "Q_CHP", t) + safe_get(results, "Q_HP", t) + 
                 safe_get(results, "Q_storage_discharge", t) + 
                 safe_get(results, "P_HP", t) * eta_wasteheat
        
        # Demand side - exactly as in heat_balance constraint
        demand = safe_get(results, "Q_industry_th", t) + safe_get(results, "Q_buildings_th", t) + 
                 safe_get(results, "Q_storage_charge", t)
        
        heat_balance_error[t] = supply - demand
    end
    
    # Check hydrogen balance for each time step - EXACT SAME AS MODEL
    hydrogen_balance_error = zeros(T)
    for t in 1:T
        # Supply side - exactly as in hydrogen_balance constraint
        supply = safe_get(results, "H_electrolysis", t) + safe_get(results, "H_storage_discharge", t)
        
        # Demand side - exactly as in hydrogen_balance constraint
        demand = safe_get(results, "H_industry", t) + safe_get(results, "H_fuelcell", t) + 
                 safe_get(results, "H_storage_charge", t) + safe_get(results, "H_HV_refuel", t)
        
        hydrogen_balance_error[t] = supply - demand
    end
    
    # Check fuel balance for each time step - EXACT SAME AS MODEL
    fuel_balance_error = zeros(T)
    for t in 1:T
        # Supply side - exactly as in fuel_balance constraint
        supply = safe_get(results, "F_E2F", t) + safe_get(results, "F_fuel", t)
        
        # Demand side - exactly as in fuel_balance constraint
        demand = safe_get(results, "F_CHP", t) + safe_get(results, "F_industry", t) + safe_get(results, "F_ICV_refuel", t)
        
        fuel_balance_error[t] = supply - demand
    end
    
    # Check synthetic fuel balance - EXACT SAME AS MODEL
    synthetic_fuel_balance_error = zeros(T)
    for t in 1:T
        # Exactly as in synthetic_fuel_balance constraint: F_E2F = P_electrolysis_fuel * eta_power_to_fuel
        balance = safe_get(results, "F_E2F", t) - safe_get(results, "P_electrolysis_fuel", t) * eta_power_to_fuel
        synthetic_fuel_balance_error[t] = balance
    end
    
    # Check electrolysis conversion - EXACT SAME AS MODEL
    electrolysis_balance_error = zeros(T)
    for t in 1:T
        # Exactly as in electrolysis_conversion constraint: H_electrolysis = P_electrolysis_H2 * eta_electrolysis
        balance = safe_get(results, "H_electrolysis", t) - safe_get(results, "P_electrolysis_H2", t) * eta_electrolysis
        electrolysis_balance_error[t] = balance
    end
    
    # Check fuel cell conversion - EXACT SAME AS MODEL
    fuelcell_balance_error = zeros(T)
    for t in 1:T
        # Exactly as in fuelcell_conversion constraint: P_fuelcell = H_fuelcell * eta_fuelcell
        balance = safe_get(results, "P_fuelcell", t) - safe_get(results, "H_fuelcell", t) * eta_fuelcell
        fuelcell_balance_error[t] = balance
    end
    
    # Check heat pump conversion - EXACT SAME AS MODEL
    heatpump_balance_error = zeros(T)
    for t in 1:T
        # Exactly as in heatpump_conversion constraint: Q_HP = P_HP * eta_heatpump
        balance = safe_get(results, "Q_HP", t) - safe_get(results, "P_HP", t) * eta_heatpump
        heatpump_balance_error[t] = balance
    end
    
    # Check CHP heat-electricity relation - EXACT SAME AS MODEL
    CHP_relation_error = zeros(T)
    for t in 1:T
        # Exactly as in CHP_heat_elec_relation constraint: Q_CHP = P_CHP / eta_CHP_elec * eta_CHP_th
        balance = safe_get(results, "Q_CHP", t) - safe_get(results, "P_CHP", t) / eta_CHP_elec * eta_CHP_th
        CHP_relation_error[t] = balance
    end
    
    # Check storage dynamics - EXACT SAME AS MODEL
    electricity_storage_error = zeros(T)
    thermal_storage_error = zeros(T)
    hydrogen_storage_error = zeros(T)
    
    for t in 2:T+1
        if t <= T
            # Electricity storage dynamics - exactly as in model
            expected_E = safe_get(results, "E_storage", t-1) * eta_elec + 
                        safe_get(results, "P_storage_charge", t-1) * eta_CH - 
                        safe_get(results, "P_storage_discharge", t-1) / eta_DC
            electricity_storage_error[t-1] = safe_get(results, "E_storage", t) - expected_E
            
            # Thermal storage dynamics - exactly as in model
            expected_Q = safe_get(results, "Q_storage", t-1) * eta_th + 
                        safe_get(results, "Q_storage_charge", t-1) * eta_CH - 
                        safe_get(results, "Q_storage_discharge", t-1) / eta_DC
            thermal_storage_error[t-1] = safe_get(results, "Q_storage", t) - expected_Q
            
            # Hydrogen storage dynamics - exactly as in model
            expected_H = safe_get(results, "H_storage", t-1) * eta_hydrogen + 
                        safe_get(results, "H_storage_charge", t-1) * eta_CH - 
                        safe_get(results, "H_storage_discharge", t-1) / eta_DC
            hydrogen_storage_error[t-1] = safe_get(results, "H_storage", t) - expected_H
        end
    end
    
    # Check vehicle energy balances - EXACT SAME AS MODEL
    ICV_energy_balance_error = zeros(T)
    EV_energy_balance_error = zeros(T)
    HV_energy_balance_error = zeros(T)
    
    for t in 2:T+1
        if t <= T
            # ICV energy balance - exactly as in ICV_SOC_dynamics constraint
            expected_SOC_ICV = safe_get(results, "SOC_ICV", t-1) - 
                              safe_get(results, "D_ICV", t-1) * alpha_ICV + 
                              safe_get(results, "F_ICV_refuel", t-1)
            ICV_energy_balance_error[t-1] = safe_get(results, "SOC_ICV", t) - expected_SOC_ICV
            
            # EV energy balance - exactly as in EV_SOC_dynamics constraint
            expected_SOC_EV = safe_get(results, "SOC_EV", t-1) - 
                             safe_get(results, "D_EV", t-1) * alpha_EV + 
                             safe_get(results, "P_EV_charge", t-1) * eta_EV_charge - 
                             safe_get(results, "P_EV_V2G", t-1) / eta_EV_discharge
            EV_energy_balance_error[t-1] = safe_get(results, "SOC_EV", t) - expected_SOC_EV
            
            # HV energy balance - exactly as in HV_SOC_dynamics constraint
            expected_SOC_HV = safe_get(results, "SOC_HV", t-1) - 
                             safe_get(results, "D_HV", t-1) * alpha_HV + 
                             safe_get(results, "H_HV_refuel", t-1)
            HV_energy_balance_error[t-1] = safe_get(results, "SOC_HV", t) - expected_SOC_HV
        end
    end
    
    # Check if all balances are within tolerance
    tolerance = 1e-3  # Relaxed tolerance for practical convergence
    
    all_balanced = (
        maximum(abs.(electricity_balance_error)) < tolerance &&
        maximum(abs.(heat_balance_error)) < tolerance &&
        maximum(abs.(hydrogen_balance_error)) < tolerance &&
        maximum(abs.(fuel_balance_error)) < tolerance &&
        maximum(abs.(synthetic_fuel_balance_error)) < tolerance &&
        maximum(abs.(electrolysis_balance_error)) < tolerance &&
        maximum(abs.(fuelcell_balance_error)) < tolerance &&
        maximum(abs.(heatpump_balance_error)) < tolerance &&
        maximum(abs.(CHP_relation_error)) < tolerance &&
        maximum(abs.(electricity_storage_error)) < tolerance &&
        maximum(abs.(thermal_storage_error)) < tolerance &&
        maximum(abs.(hydrogen_storage_error)) < tolerance &&
        maximum(abs.(ICV_energy_balance_error)) < tolerance &&
        maximum(abs.(EV_energy_balance_error)) < tolerance &&
        maximum(abs.(HV_energy_balance_error)) < tolerance
    )
    # Print detailed balance errors for debugging
    # @printf("Electricity Balance Error: %.4f\n", maximum(abs.(electricity_balance_error)))
    # @printf("Heat Balance Error: %.4f\n", maximum(abs.(heat_balance_error)))
    # @printf("Hydrogen Balance Error: %.4f\n", maximum(abs.(hydrogen_balance_error)))
    # @printf("Fuel Balance Error: %.4f\n", maximum(abs.(fuel_balance_error)))
    # @printf("Synthetic Fuel Balance Error: %.4f\n", maximum(abs.(synthetic_fuel_balance_error)))
    # @printf("Electrolysis Balance Error: %.4f\n", maximum(abs.(electrolysis_balance_error)))
    # @printf("Fuel Cell Balance Error: %.4f\n", maximum(abs.(fuelcell_balance_error)))
    # @printf("Heat Pump Balance Error: %.4f\n", maximum(abs.(heatpump_balance_error)))
    # @printf("CHP Relation Error: %.4f\n", maximum(abs.(CHP_relation_error)))
    # @printf("Electricity Storage Error: %.4f\n", maximum(abs.(electricity_storage_error)))
    # @printf("Thermal Storage Error: %.4f\n", maximum(abs.(thermal_storage_error)))
    # @printf("Hydrogen Storage Error: %.4f\n", maximum(abs.(hydrogen_storage_error)))
    # @printf("ICV Energy Balance Error: %.4f\n", maximum(abs.(ICV_energy_balance_error)))
    # @printf("EV Energy Balance Error: %.4f\n", maximum(abs.(EV_energy_balance_error)))
    # @printf("HV Energy Balance Error: %.4f\n", maximum(abs.(HV_energy_balance_error)))
    
    # # Print parameter values for debugging
    # @printf("eta_power_to_fuel used: %.4f\n", eta_power_to_fuel)
    
    return all_balanced
end

# Helper function to safely get values from results dictionary
function safe_get(results, key, index)
    if haskey(results, key) && isa(results[key], Vector) && length(results[key]) >= index
        return results[key][index]
    else
        return 0.0
    end
end

# Function to analyze system efficiency
function analyze_system_efficiency(results, T, params)
    # Validate inputs
    validation = validate_analysis_inputs(results, T, params)
    if !validation["success"]
        return validation
    end
    params = validation["params"]
    
    # Calculate basic energy totals
    energy_totals = calculate_energy_totals(results, T)
    
    # Calculate total energy inputs and outputs
    total_energy_input = energy_totals["total_grid"] + energy_totals["total_solar"] + 
                        energy_totals["total_wind"] + energy_totals["total_fuel_external"] / params["eta_power_to_fuel"]
    
    # Calculate useful energy outputs
    total_electricity_demand = safe_sum(results, "P_industry_elec", T) + safe_sum(results, "P_buildings_elec", T) + 
                              safe_sum(results, "P_EV_charge", T) - safe_sum(results, "P_EV_V2G", T)
    total_heat_demand = safe_sum(results, "Q_industry_th", T) + safe_sum(results, "Q_buildings_th", T)
    total_hydrogen_demand = energy_totals["total_hydrogen_industry"] + energy_totals["total_hydrogen_fuelcell"] + 
                           energy_totals["total_hydrogen_vehicles"]
    
    total_energy_output = total_electricity_demand + total_heat_demand / params["eta_heatpump"] + 
                         total_hydrogen_demand / params["eta_electrolysis"]
    
    # Calculate overall system efficiency
    system_efficiency = total_energy_output / total_energy_input * 100
    
    # Calculate component efficiencies
    component_efficiencies = calculate_component_efficiencies(results, params, energy_totals, T)
    
    # Calculate storage efficiencies
    storage_efficiencies = calculate_storage_efficiencies(results, T)
    
    # Calculate carbon intensity
    gamma_elec, gamma_fuel = extract_gamma_values(results, params, T)
    emissions = calculate_emissions(results, params, gamma_elec, gamma_fuel, T)
    carbon_intensity = emissions["net_emissions"] / total_energy_output
    
    # Combine all efficiency metrics
    efficiency_metrics = merge(component_efficiencies, storage_efficiencies)
    efficiency_metrics["system_efficiency"] = system_efficiency
    efficiency_metrics["carbon_intensity"] = carbon_intensity
    efficiency_metrics["success"] = true
    
    return efficiency_metrics
end

# Helper function to calculate component efficiencies
function calculate_component_efficiencies(results, params, energy_totals, T)
    # CHP efficiency
    CHP_efficiency = if energy_totals["total_fuel_CHP"] > 0
        (energy_totals["total_CHP_elec"] + energy_totals["total_CHP_heat"] / params["eta_heatpump"]) / 
        (energy_totals["total_fuel_CHP"] / params["eta_power_to_fuel"]) * 100
    else
        0
    end
    
    # Heat pump efficiency (COP)
    heat_pump_COP = if safe_sum(results, "P_HP", T) > 0
        safe_sum(results, "Q_HP", T) / safe_sum(results, "P_HP", T)
    else
        0
    end
    
    # Electrolysis efficiency
    electrolysis_efficiency = if safe_sum(results, "P_electrolysis", T) > 0
        energy_totals["total_hydrogen_electrolysis"] / safe_sum(results, "P_electrolysis", T) * 100
    else
        0
    end
    
    # Fuel cell efficiency
    fuelcell_efficiency = if energy_totals["total_hydrogen_fuelcell"] > 0
        energy_totals["total_fuelcell"] / energy_totals["total_hydrogen_fuelcell"] * 100
    else
        0
    end
    
    # V2G efficiency
    V2G_efficiency = if safe_sum(results, "P_EV_charge", T) > 0
        safe_sum(results, "P_EV_V2G", T) / safe_sum(results, "P_EV_charge", T) * 
        params["eta_EV_charge"] * params["eta_EV_discharge"] * 100
    else
        0
    end
    
    return Dict(
        "CHP_efficiency" => CHP_efficiency,
        "heat_pump_COP" => heat_pump_COP,
        "electrolysis_efficiency" => electrolysis_efficiency,
        "fuelcell_efficiency" => fuelcell_efficiency,
        "V2G_efficiency" => V2G_efficiency
    )
end

# Helper function to calculate storage efficiencies
function calculate_storage_efficiencies(results, T)
    electricity_storage_efficiency = if safe_sum(results, "P_storage_charge", T) > 0
        safe_sum(results, "P_storage_discharge", T) / safe_sum(results, "P_storage_charge", T) * 100
    else
        0
    end
    
    thermal_storage_efficiency = if safe_sum(results, "Q_storage_charge", T) > 0
        safe_sum(results, "Q_storage_discharge", T) / safe_sum(results, "Q_storage_charge", T) * 100
    else
        0
    end
    
    hydrogen_storage_efficiency = if safe_sum(results, "H_storage_charge", T) > 0
        safe_sum(results, "H_storage_discharge", T) / safe_sum(results, "H_storage_charge", T) * 100
    else
        0
    end
    
    return Dict(
        "electricity_storage_efficiency" => electricity_storage_efficiency,
        "thermal_storage_efficiency" => thermal_storage_efficiency,
        "hydrogen_storage_efficiency" => hydrogen_storage_efficiency
    )
end

# Function to export results to CSV
function export_results_to_csv(results, T)
    # Check if results is a valid dictionary
    if !isa(results, Dict) || isempty(results)
        return nothing
    end
    
    # First, collect all keys that exist in the results
    csv_columns = Any["Time" => 1:T]
    
    # Add all available result keys
    for key in keys(results)
        if isa(results[key], Vector) && length(results[key]) == T
            push!(csv_columns, key => results[key])
        end
    end
    
    # Add calculated emissions if the required keys exist
    if haskey(results, "gamma_elec") && haskey(results, "P_grid") && 
       haskey(results, "gamma_fuel") && haskey(results, "F_CHP") && haskey(results, "F_industry") && haskey(results, "F_ICV_refuel")
        emissions = results["gamma_elec"] .* results["P_grid"] + results["gamma_fuel"] * (results["F_CHP"] + results["F_industry"] + results["F_ICV_refuel"])
        push!(csv_columns, "Emissions_total" => emissions)
    end
    
    # Create DataFrame and write to CSV
    # Extract column names and values from the pairs in csv_columns
    column_names = [Symbol(pair.first) for pair in csv_columns]
    column_values = [pair.second for pair in csv_columns]
    
    results_df = DataFrame(column_values, column_names, makeunique=true)
    CSV.write("energy_system_results.csv", results_df)
    
    return results_df
end
