using JuMP
using Ipopt

# Define the model
function create_low_carbon_energy_system_model(params::Dict)
    # ================================================================
    # PARAMETER EXTRACTION
    # ================================================================
    
    # Basic system parameters
    T = params["T"]                      # Number of time steps
    gamma_elec = params["gamma_elec"]    # Carbon intensity of grid electricity at each time step
    gamma_fuel = params["gamma_fuel"]    # Carbon intensity of fuels
    lambda = params["lambda"]            # Carbon emission penalty factor
    
    # Cost parameters
    c_grid = params["c_grid"]            # Time-varying electricity price
    c_solar = params["c_solar"]          # Cost of solar generation
    c_wind = params["c_wind"]            # Cost of wind generation
    c_fuel = params["c_fuel"]            # Cost of fuel
    c_cert = params["c_cert"]            # Cost of green certificates
    
    # Transportation parameters
    D_total = params["D_total"]          # Total transportation demand for each day
    alpha_ICV = params["alpha_ICV"]      # Energy consumption per vehicle-kilometer (ICV)
    alpha_EV = params["alpha_EV"]        # Energy consumption per vehicle-kilometer (EV)
    alpha_HV = params["alpha_HV"]        # Energy consumption per vehicle-kilometer (HV)
    
    # Electrification ratios
    EV_ratio = get(params, "EV_ratio", 0.3)     # Electric vehicle ratio
    HV_ratio = get(params, "HV_ratio", 0.2)     # Hydrogen vehicle ratio  
    ICV_ratio = get(params, "ICV_ratio", 0.5)   # Internal combustion vehicle ratio
    
    # Component capacities
    P_solar_rated = get(params, "P_solar_rated", 1000.0)      # Maximum solar capacity
    P_wind_rated = get(params, "P_wind_rated", 800.0)         # Maximum wind capacity
    P_heatpump_max = get(params, "P_heatpump_max", 500.0)     # Maximum heat pump capacity
    P_electrolysis_max = get(params, "P_electrolysis_max", 300.0)   # Maximum electrolysis capacity
    P_CHP_max = get(params, "P_CHP_max", 400.0)                    # Maximum CHP capacity
    P_fuelcell_max = params["P_fuelcell_max"]    # Maximum fuel cell capacity
    
    # Extract renewable generation potentials
    P_solar_max = params["P_solar_max"]  # Maximum solar output at each time step
    P_wind_max = params["P_wind_max"]    # Maximum wind output at each time step
    renewable_mandate = params["renewable_mandate"]  # Renewable mandate percentage
    
    # Extract storage parameters
    storage_params = extract_storage_parameters(params)
    
    # Extract conversion efficiency parameters
    efficiency_params = extract_efficiency_parameters(params)
    
    # Extract emissions and carbon parameters
    carbon_params = extract_carbon_parameters(params)
    
    # Extract demand profiles
    demand_params = extract_demand_parameters(params)
    
    # Extract vehicle parameters
    vehicle_params = extract_vehicle_parameters(params)
    
    # Demand response parameters
    DR_ENABLED = true # Set to false if demand response is not enabled
    range = DR_ENABLED ? 0.2 : 0.0 # Demand response range
    
    # ================================================================
    # MODEL CREATION
    # ================================================================
    
    model = Model(Ipopt.Optimizer)
    set_silent(model)
    
    # ================================================================
    # VARIABLE DEFINITIONS
    # ================================================================
    
    # Energy generation variables
    generation_vars = create_generation_variables(model, T)
    
    # Energy conversion variables
    conversion_vars = create_conversion_variables(model, T)
    
    # Storage variables
    storage_vars = create_storage_variables(model, T)
    
    # Demand variables
    demand_vars = create_demand_variables(model, T, range)
    
    # Transportation variables
    transport_vars = create_transportation_variables(model, T)
    
    # Environmental variables
    env_vars = create_environmental_variables(model, T)
    
    # ================================================================
    # CONSTRAINT DEFINITIONS
    # ================================================================
    
    # Component capacity constraints
    add_capacity_constraints(model, generation_vars, conversion_vars, T, 
                           P_solar_rated, P_wind_rated, P_solar_max, P_wind_max,
                           P_heatpump_max, P_electrolysis_max, P_CHP_max, P_fuelcell_max)
    
    # Energy balance constraints
    add_energy_balance_constraints(model, generation_vars, conversion_vars, storage_vars, 
                                 demand_vars, transport_vars, env_vars, T, efficiency_params)
    
    # Storage constraints
    add_storage_constraints(model, storage_vars, T, storage_params, efficiency_params)
    
    # Demand constraints
    add_demand_constraints(model, demand_vars, T, demand_params, range)
    
    # Transportation constraints
    add_transportation_constraints(model, transport_vars, T, D_total, vehicle_params,
                                 EV_ratio, HV_ratio, ICV_ratio, alpha_ICV, alpha_EV, alpha_HV)
    
    # Environmental constraints
    add_environmental_constraints(model, generation_vars, conversion_vars, env_vars, T,
                                carbon_params, gamma_elec, gamma_fuel, renewable_mandate)
    
    # ================================================================
    # OBJECTIVE FUNCTION
    # ================================================================
    
    @objective(model, Min,
        sum(
            c_grid[t] * generation_vars[:P_grid][t] +     # Cost of grid electricity
            c_fuel * generation_vars[:F_fuel][t] +        # Cost of fuel
            c_cert * env_vars[:Cert_purchase][t] +        # Cost of green certificates
            c_solar * generation_vars[:P_solar][t] +      # Cost of solar generation
            c_wind * generation_vars[:P_wind][t] +        # Cost of wind generation
            lambda * env_vars[:Carbon_residual][t]        # Carbon penalty
            for t in 1:T
        )
    )

    return model
end

# ================================================================
# HELPER FUNCTIONS FOR PARAMETER EXTRACTION
# ================================================================

function extract_storage_parameters(params::Dict)
    return Dict(
        "E_storage_0" => params["E_storage_0"],
        "Q_storage_0" => params["Q_storage_0"],
        "H_storage_0" => params["H_storage_0"],
        "E_storage_max" => params["E_storage_max"],
        "Q_storage_max" => params["Q_storage_max"],
        "H_storage_max" => params["H_storage_max"],
        "E_storage_min" => params["E_storage_min"],
        "Q_storage_min" => params["Q_storage_min"],
        "H_storage_min" => params["H_storage_min"],
        "P_storage_max" => params["P_storage_max"],
        "Q_storage_max_rate" => params["Q_storage_max_rate"],
        "H_storage_max_rate" => params["H_storage_max_rate"]
    )
end

function extract_efficiency_parameters(params::Dict)
    return Dict(
        "eta_electrolysis" => params["eta_electrolysis"],
        "eta_CHP" => params["eta_CHP"],
        "eta_CHP_elec" => params["eta_CHP_elec"],
        "eta_CHP_th" => params["eta_CHP_th"],
        "eta_heatpump" => params["eta_heatpump"],
        "eta_fuelcell" => params["eta_fuelcell"],
        "eta_power_to_fuel" => params["eta_power_to_fuel"],
        "eta_wasteheat" => params["eta_wasteheat"],
        "eta_CH" => params["eta_CH"],
        "eta_DC" => params["eta_DC"],
        "eta_elec" => params["eta_elec"],
        "eta_th" => params["eta_th"],
        "eta_hydrogen" => params["eta_hydrogen"],
        "eta_EV_charge" => params["eta_EV_charge"],
        "eta_EV_discharge" => params["eta_EV_discharge"]
    )
end

function extract_carbon_parameters(params::Dict)
    return Dict(
        "CO2_budget" => params["CO2_budget"],
        "eta_CCUS" => params["eta_CCUS"],
        "eta_CCUS_PtF" => params["eta_CCUS_PtF"],
        "eta_C2F" => params["eta_C2F"],
        "eta_CCUS_loss" => params["eta_CCUS_loss"]
    )
end

function extract_demand_parameters(params::Dict)
    return Dict(
        "P_industry_elec_base" => params["P_industry_elec_base"],
        "Q_industry_th_base" => params["Q_industry_th_base"],
        "H_industry_base" => params["H_industry_base"],
        "F_industry_base" => params["F_industry_base"],
        "P_buildings_elec_base" => params["P_buildings_elec_base"],
        "Q_buildings_th_base" => params["Q_buildings_th_base"]
    )
end

function extract_vehicle_parameters(params::Dict)
    return Dict(
        "SOC_EV_0" => params["SOC_EV_0"],
        "SOC_EV_min" => params["SOC_EV_min"],
        "SOC_EV_max" => params["SOC_EV_max"],
        "P_EV_max" => params["P_EV_max"],
        "eta_EV_charge" => params["eta_EV_charge"],      # Add missing EV charging efficiency
        "eta_EV_discharge" => params["eta_EV_discharge"], # Add missing EV discharging efficiency
        "SOC_ICV_0" => params["SOC_ICV_0"],
        "SOC_ICV_min" => params["SOC_ICV_min"],
        "SOC_ICV_max" => params["SOC_ICV_max"],
        "F_ICV_max" => params["F_ICV_max"],
        "SOC_HV_0" => params["SOC_HV_0"],
        "SOC_HV_min" => params["SOC_HV_min"],
        "SOC_HV_max" => params["SOC_HV_max"],
        "H_HV_max" => params["H_HV_max"]
    )
end

# ================================================================
# HELPER FUNCTIONS FOR VARIABLE CREATION
# ================================================================

function create_generation_variables(model, T)
    @variable(model, P_grid[1:T] >= 0)          # Power from the grid
    @variable(model, P_solar[1:T] >= 0)         # Solar power generation
    @variable(model, P_wind[1:T] >= 0)          # Wind power generation
    @variable(model, P_CHP[1:T] >= 0)           # Electricity from CHP
    @variable(model, Q_CHP[1:T] >= 0)           # Heat from CHP
    @variable(model, F_CHP[1:T] >= 0)           # Fuel input to CHP
    @variable(model, P_fuelcell[1:T] >= 0)      # Power from fuel cells
    @variable(model, F_fuel[1:T] >= 0)          # External fuel input
    @variable(model, F_E2F[1:T] >= 0)           # Synthetic fuel from electrolysis
    
    return Dict(
        :P_grid => P_grid, :P_solar => P_solar, :P_wind => P_wind,
        :P_CHP => P_CHP, :Q_CHP => Q_CHP, :F_CHP => F_CHP,
        :P_fuelcell => P_fuelcell, :F_fuel => F_fuel, :F_E2F => F_E2F
    )
end

function create_conversion_variables(model, T)
    @variable(model, P_electrolysis_H2[1:T] >= 0)   # Power for hydrogen electrolysis
    @variable(model, P_electrolysis_fuel[1:T] >= 0) # Power for fuel synthesis
    @variable(model, H_electrolysis[1:T] >= 0)      # Hydrogen from electrolysis
    @variable(model, H_fuelcell[1:T] >= 0)          # Hydrogen for fuel cells
    @variable(model, P_HP[1:T] >= 0)                # Power for heat pumps
    @variable(model, Q_HP[1:T] >= 0)                # Heat from heat pumps
    
    return Dict(
        :P_electrolysis_H2 => P_electrolysis_H2, :P_electrolysis_fuel => P_electrolysis_fuel,
        :H_electrolysis => H_electrolysis, :H_fuelcell => H_fuelcell,
        :P_HP => P_HP, :Q_HP => Q_HP
    )
end

function create_storage_variables(model, T)
    # Storage levels
    @variable(model, E_storage[1:T+1] >= 0)       # Electricity storage level
    @variable(model, Q_storage[1:T+1] >= 0)       # Thermal storage level
    @variable(model, H_storage[1:T+1] >= 0)       # Hydrogen storage level
    
    # Storage operations
    @variable(model, P_storage_charge[1:T] >= 0)     # Electricity storage charging
    @variable(model, P_storage_discharge[1:T] >= 0)  # Electricity storage discharging
    @variable(model, Q_storage_charge[1:T] >= 0)     # Thermal storage charging
    @variable(model, Q_storage_discharge[1:T] >= 0)  # Thermal storage discharging
    @variable(model, H_storage_charge[1:T] >= 0)     # Hydrogen storage charging
    @variable(model, H_storage_discharge[1:T] >= 0)  # Hydrogen storage discharging
    
    return Dict(
        :E_storage => E_storage, :Q_storage => Q_storage, :H_storage => H_storage,
        :P_storage_charge => P_storage_charge, :P_storage_discharge => P_storage_discharge,
        :Q_storage_charge => Q_storage_charge, :Q_storage_discharge => Q_storage_discharge,
        :H_storage_charge => H_storage_charge, :H_storage_discharge => H_storage_discharge
    )
end

function create_demand_variables(model, T, range)
    # Base demand
    @variable(model, P_industry_elec[1:T] >= 0)     # Industry electricity demand
    @variable(model, Q_industry_th[1:T] >= 0)       # Industry thermal demand
    @variable(model, H_industry[1:T] >= 0)          # Industry hydrogen demand
    @variable(model, F_industry[1:T] >= 0)          # Industry fuel demand
    @variable(model, P_buildings_elec[1:T] >= 0)    # Buildings electricity demand
    @variable(model, Q_buildings_th[1:T] >= 0)      # Buildings thermal demand
    
    # Demand response variables
    @variable(model, ΔP_industry_elec_pos[1:T] >= 0)  # Industry demand increase
    @variable(model, ΔP_industry_elec_neg[1:T] >= 0)  # Industry demand decrease
    @variable(model, ΔP_buildings_elec_pos[1:T] >= 0) # Buildings demand increase
    @variable(model, ΔP_buildings_elec_neg[1:T] >= 0) # Buildings demand decrease
    
    return Dict(
        :P_industry_elec => P_industry_elec, :Q_industry_th => Q_industry_th,
        :H_industry => H_industry, :F_industry => F_industry,
        :P_buildings_elec => P_buildings_elec, :Q_buildings_th => Q_buildings_th,
        :ΔP_industry_elec_pos => ΔP_industry_elec_pos, :ΔP_industry_elec_neg => ΔP_industry_elec_neg,
        :ΔP_buildings_elec_pos => ΔP_buildings_elec_pos, :ΔP_buildings_elec_neg => ΔP_buildings_elec_neg
    )
end

function create_transportation_variables(model, T)
    # Transportation demand
    @variable(model, D_ICV[1:T] >= 0)               # Distance traveled by ICVs
    @variable(model, D_EV[1:T] >= 0)                # Distance traveled by EVs
    @variable(model, D_HV[1:T] >= 0)                # Distance traveled by HVs
    
    # Vehicle energy and refueling
    @variable(model, F_ICV_refuel[1:T] >= 0)        # Fuel refueling for ICVs
    @variable(model, SOC_ICV[1:T+1] >= 0)           # State of charge of ICV fleet
    @variable(model, H_HV_refuel[1:T] >= 0)         # Hydrogen refueling for HVs
    @variable(model, SOC_HV[1:T+1] >= 0)            # State of charge of HV fleet
    @variable(model, SOC_EV[1:T+1] >= 0)            # State of charge of EV fleet
    @variable(model, P_EV_charge[1:T] >= 0)         # Power for EV charging
    @variable(model, P_EV_V2G[1:T] >= 0)            # Power from EV discharging (V2G)
    
    return Dict(
        :D_ICV => D_ICV, :D_EV => D_EV, :D_HV => D_HV,
        :F_ICV_refuel => F_ICV_refuel, :SOC_ICV => SOC_ICV,
        :H_HV_refuel => H_HV_refuel, :SOC_HV => SOC_HV,
        :SOC_EV => SOC_EV, :P_EV_charge => P_EV_charge, :P_EV_V2G => P_EV_V2G
    )
end

function create_environmental_variables(model, T)
    @variable(model, CO2_captured[1:T] >= 0)        # CO2 captured
    @variable(model, P_CCUS[1:T] >= 0)              # Power for carbon capture
    @variable(model, Emissions_total[1:T] >= 0)     # Total emissions
    @variable(model, Cert_purchase[1:T] == 0)       # Green certificates purchased
    @variable(model, Carbon_residual[1:T] >= 0)     # Carbon residual
    
    return Dict(
        :CO2_captured => CO2_captured, :P_CCUS => P_CCUS,
        :Emissions_total => Emissions_total, :Cert_purchase => Cert_purchase,
        :Carbon_residual => Carbon_residual
    )
end

# ================================================================
# HELPER FUNCTIONS FOR CONSTRAINT CREATION
# ================================================================

function add_capacity_constraints(model, generation_vars, conversion_vars, T, 
                                P_solar_rated, P_wind_rated, P_solar_max, P_wind_max,
                                P_heatpump_max, P_electrolysis_max, P_CHP_max, P_fuelcell_max)
    
    # Renewable generation capacity constraints
    @constraint(model, solar_capacity[t=1:T],
        generation_vars[:P_solar][t] <= min(P_solar_max[t], P_solar_rated))
    
    @constraint(model, wind_capacity[t=1:T],
        generation_vars[:P_wind][t] <= min(P_wind_max[t], P_wind_rated))
    
    # Component capacity constraints
    @constraint(model, heatpump_capacity[t=1:T],
        conversion_vars[:P_HP][t] <= P_heatpump_max)
    
    @constraint(model, electrolysis_capacity[t=1:T],
        conversion_vars[:P_electrolysis_H2][t] + conversion_vars[:P_electrolysis_fuel][t] <= P_electrolysis_max)
    
    @constraint(model, CHP_capacity[t=1:T],
        generation_vars[:P_CHP][t] <= P_CHP_max)
    
    @constraint(model, fuelcell_capacity[t=1:T],
        generation_vars[:P_fuelcell][t] <= P_fuelcell_max)
end

function add_energy_balance_constraints(model, generation_vars, conversion_vars, storage_vars, 
                                      demand_vars, transport_vars, env_vars, T, efficiency_params)
    
    # Electricity balance
    @constraint(model, electricity_balance[t=1:T],
        generation_vars[:P_grid][t] + generation_vars[:P_solar][t] + generation_vars[:P_wind][t] + 
        generation_vars[:P_CHP][t] + generation_vars[:P_fuelcell][t] + 
        storage_vars[:P_storage_discharge][t] + transport_vars[:P_EV_V2G][t] ==
        demand_vars[:P_industry_elec][t] + demand_vars[:P_buildings_elec][t] + 
        conversion_vars[:P_electrolysis_H2][t] + conversion_vars[:P_electrolysis_fuel][t] + 
        conversion_vars[:P_HP][t] + storage_vars[:P_storage_charge][t] + 
        transport_vars[:P_EV_charge][t] + env_vars[:P_CCUS][t])
    
    # Heat balance
    @constraint(model, heat_balance[t=1:T],
        generation_vars[:Q_CHP][t] + conversion_vars[:Q_HP][t] + storage_vars[:Q_storage_discharge][t] + 
        conversion_vars[:P_HP][t] * efficiency_params["eta_wasteheat"] ==
        demand_vars[:Q_industry_th][t] + demand_vars[:Q_buildings_th][t] + storage_vars[:Q_storage_charge][t])
    
    # Hydrogen balance
    @constraint(model, hydrogen_balance[t=1:T],
        conversion_vars[:H_electrolysis][t] + storage_vars[:H_storage_discharge][t] ==
        demand_vars[:H_industry][t] + conversion_vars[:H_fuelcell][t] + 
        storage_vars[:H_storage_charge][t] + transport_vars[:H_HV_refuel][t])
    
    # Fuel balance
    @constraint(model, fuel_balance[t=1:T], 
        generation_vars[:F_CHP][t] + demand_vars[:F_industry][t] + transport_vars[:F_ICV_refuel][t] == 
        generation_vars[:F_E2F][t] + generation_vars[:F_fuel][t])
    
    # Conversion process constraints
    add_conversion_constraints(model, generation_vars, conversion_vars, T, efficiency_params)
end

function add_conversion_constraints(model, generation_vars, conversion_vars, T, efficiency_params)
    # CHP fuel balance
    @constraint(model, CHP_fuel_balance[t=1:T],
        generation_vars[:F_CHP][t] * efficiency_params["eta_CHP"] / efficiency_params["eta_power_to_fuel"] == 
        generation_vars[:P_CHP][t] + generation_vars[:Q_CHP][t] / efficiency_params["eta_heatpump"])
    
    # CHP heat-electricity relation
    @constraint(model, CHP_heat_elec_relation[t=1:T],
        generation_vars[:Q_CHP][t] == generation_vars[:P_CHP][t] / efficiency_params["eta_CHP_elec"] * efficiency_params["eta_CHP_th"])
    
    # Synthetic fuel balance
    @constraint(model, synthetic_fuel_balance[t=1:T], 
        generation_vars[:F_E2F][t] == conversion_vars[:P_electrolysis_fuel][t] * efficiency_params["eta_power_to_fuel"])
    
    # Electrolysis conversion
    @constraint(model, electrolysis_conversion[t=1:T],
        conversion_vars[:H_electrolysis][t] == conversion_vars[:P_electrolysis_H2][t] * efficiency_params["eta_electrolysis"])
    
    # Fuel cell conversion
    @constraint(model, fuelcell_conversion[t=1:T],
        generation_vars[:P_fuelcell][t] == conversion_vars[:H_fuelcell][t] * efficiency_params["eta_fuelcell"])
    
    # Heat pump conversion
    @constraint(model, heatpump_conversion[t=1:T],
        conversion_vars[:Q_HP][t] == conversion_vars[:P_HP][t] * efficiency_params["eta_heatpump"])
end

function add_storage_constraints(model, storage_vars, T, storage_params, efficiency_params)
    # Storage dynamics
    @constraint(model, electricity_storage_dynamics[t=2:T+1],
        storage_vars[:E_storage][t] == storage_vars[:E_storage][t-1] * efficiency_params["eta_elec"] + 
        storage_vars[:P_storage_charge][t-1] * efficiency_params["eta_CH"] - 
        storage_vars[:P_storage_discharge][t-1] / efficiency_params["eta_DC"])
    
    @constraint(model, thermal_storage_dynamics[t=2:T+1],
        storage_vars[:Q_storage][t] == storage_vars[:Q_storage][t-1] * efficiency_params["eta_th"] + 
        storage_vars[:Q_storage_charge][t-1] * efficiency_params["eta_CH"] - 
        storage_vars[:Q_storage_discharge][t-1] / efficiency_params["eta_DC"])
    
    @constraint(model, hydrogen_storage_dynamics[t=2:T+1],
        storage_vars[:H_storage][t] == storage_vars[:H_storage][t-1] * efficiency_params["eta_hydrogen"] + 
        storage_vars[:H_storage_charge][t-1] * efficiency_params["eta_CH"] - 
        storage_vars[:H_storage_discharge][t-1] / efficiency_params["eta_DC"])
    
    # Initial and final storage levels
    @constraint(model, electricity_storage_initial, storage_vars[:E_storage][1] == storage_params["E_storage_0"])
    @constraint(model, thermal_storage_initial, storage_vars[:Q_storage][1] == storage_params["Q_storage_0"])
    @constraint(model, hydrogen_storage_initial, storage_vars[:H_storage][1] == storage_params["H_storage_0"])
    
    @constraint(model, electricity_storage_final, storage_vars[:E_storage][T+1] == storage_params["E_storage_0"])
    @constraint(model, thermal_storage_final, storage_vars[:Q_storage][T+1] == storage_params["Q_storage_0"])
    @constraint(model, hydrogen_storage_final, storage_vars[:H_storage][T+1] == storage_params["H_storage_0"])
    
    # Storage capacity constraints
    @constraint(model, electricity_storage_capacity[t=1:T],
        storage_params["E_storage_min"] <= storage_vars[:E_storage][t] <= storage_params["E_storage_max"])
    
    @constraint(model, thermal_storage_capacity[t=1:T],
        storage_params["Q_storage_min"] <= storage_vars[:Q_storage][t] <= storage_params["Q_storage_max"])
    
    @constraint(model, hydrogen_storage_capacity[t=1:T],
        storage_params["H_storage_min"] <= storage_vars[:H_storage][t] <= storage_params["H_storage_max"])
    
    # Storage rate constraints
    @constraint(model, electricity_storage_rate[t=1:T],
        storage_vars[:P_storage_charge][t] <= storage_params["P_storage_max"])
    @constraint(model, electricity_discharge_rate[t=1:T],
        storage_vars[:P_storage_discharge][t] <= storage_params["P_storage_max"])
    
    @constraint(model, thermal_storage_rate[t=1:T],
        storage_vars[:Q_storage_charge][t] <= storage_params["Q_storage_max_rate"])
    @constraint(model, thermal_discharge_rate[t=1:T],
        storage_vars[:Q_storage_discharge][t] <= storage_params["Q_storage_max_rate"])
    
    @constraint(model, hydrogen_storage_rate[t=1:T],
        storage_vars[:H_storage_charge][t] <= storage_params["H_storage_max_rate"])
    @constraint(model, hydrogen_discharge_rate[t=1:T],
        storage_vars[:H_storage_discharge][t] <= storage_params["H_storage_max_rate"])
end

function add_demand_constraints(model, demand_vars, T, demand_params, range)
    # Industry demand constraints
    @constraint(model, industry_elec_demand[t=1:T],
        demand_vars[:P_industry_elec][t] == demand_params["P_industry_elec_base"][t] + 
        demand_vars[:ΔP_industry_elec_pos][t] - demand_vars[:ΔP_industry_elec_neg][t])
    
    @constraint(model, industry_thermal_demand[t=1:T],
        demand_vars[:Q_industry_th][t] == demand_params["Q_industry_th_base"][t])
    
    @constraint(model, industry_hydrogen_demand[t=1:T],
        demand_vars[:H_industry][t] == demand_params["H_industry_base"][t])
    
    @constraint(model, industry_fuel_demand[t=1:T],
        demand_vars[:F_industry][t] == demand_params["F_industry_base"][t])
    
    # Buildings demand constraints
    @constraint(model, buildings_elec_demand[t=1:T],
        demand_vars[:P_buildings_elec][t] == demand_params["P_buildings_elec_base"][t] + 
        demand_vars[:ΔP_buildings_elec_pos][t] - demand_vars[:ΔP_buildings_elec_neg][t])
    
    @constraint(model, buildings_thermal_demand[t=1:T],
        demand_vars[:Q_buildings_th][t] == demand_params["Q_buildings_th_base"][t])
    
    # Demand response constraints
    @constraint(model, buildings_elec_pos[t=1:T],
        demand_vars[:ΔP_buildings_elec_pos][t] <= range * demand_params["P_buildings_elec_base"][t])
    @constraint(model, buildings_elec_neg[t=1:T],
        demand_vars[:ΔP_buildings_elec_neg][t] <= range * demand_params["P_buildings_elec_base"][t])
    @constraint(model, industry_elec_pos[t=1:T],
        demand_vars[:ΔP_industry_elec_pos][t] <= range * demand_params["P_industry_elec_base"][t])
    @constraint(model, industry_elec_neg[t=1:T],
        demand_vars[:ΔP_industry_elec_neg][t] <= range * demand_params["P_industry_elec_base"][t])
    
    # Demand response balance constraints
    @constraint(model, buildings_elec_balance, 
        sum(demand_vars[:ΔP_buildings_elec_pos]) == sum(demand_vars[:ΔP_buildings_elec_neg]))
    @constraint(model, industry_elec_balance, 
        sum(demand_vars[:ΔP_industry_elec_pos]) == sum(demand_vars[:ΔP_industry_elec_neg]))
end

function add_transportation_constraints(model, transport_vars, T, D_total, vehicle_params,
                                      EV_ratio, HV_ratio, ICV_ratio, alpha_ICV, alpha_EV, alpha_HV)
    
    # Transportation demand constraints
    @constraint(model, transportation_demand[t=1:T],
        transport_vars[:D_ICV][t] + transport_vars[:D_EV][t] + transport_vars[:D_HV][t] == D_total[t])
    
    # Electrification ratio constraints
    total_demand = sum(D_total[t] for t in 1:T)
    @constraint(model, transportation_electrification_EV,
        sum(transport_vars[:D_EV][t] for t in 1:T) >= EV_ratio * total_demand * 0.9)
    @constraint(model, transportation_electrification_EV_max,
        sum(transport_vars[:D_EV][t] for t in 1:T) <= EV_ratio * total_demand * 1.1)
    
    @constraint(model, transportation_electrification_HV,
        sum(transport_vars[:D_HV][t] for t in 1:T) >= HV_ratio * total_demand * 0.9)
    @constraint(model, transportation_electrification_HV_max,
        sum(transport_vars[:D_HV][t] for t in 1:T) <= HV_ratio * total_demand * 1.1)
    
    @constraint(model, transportation_electrification_ICV,
        sum(transport_vars[:D_ICV][t] for t in 1:T) >= ICV_ratio * total_demand * 0.9)
    @constraint(model, transportation_electrification_ICV_max,
        sum(transport_vars[:D_ICV][t] for t in 1:T) <= ICV_ratio * total_demand * 1.1)
    
    # Vehicle energy dynamics and constraints
    add_vehicle_constraints(model, transport_vars, T, vehicle_params, alpha_ICV, alpha_EV, alpha_HV)
end

function add_vehicle_constraints(model, transport_vars, T, vehicle_params, alpha_ICV, alpha_EV, alpha_HV)
    # ICV constraints
    @constraint(model, ICV_SOC_dynamics[t=2:T+1],
        transport_vars[:SOC_ICV][t] == transport_vars[:SOC_ICV][t-1] - transport_vars[:D_ICV][t-1] * alpha_ICV + transport_vars[:F_ICV_refuel][t-1])
    
    @constraint(model, ICV_SOC_initial, transport_vars[:SOC_ICV][1] == vehicle_params["SOC_ICV_0"])
    @constraint(model, ICV_SOC_final, transport_vars[:SOC_ICV][T+1] == vehicle_params["SOC_ICV_0"])
    @constraint(model, ICV_SOC_limits[t=1:T],
        vehicle_params["SOC_ICV_min"] <= transport_vars[:SOC_ICV][t] <= vehicle_params["SOC_ICV_max"])
    @constraint(model, ICV_refuel_rate[t=1:T], transport_vars[:F_ICV_refuel][t] <= vehicle_params["F_ICV_max"])
    
    # HV constraints
    @constraint(model, HV_SOC_dynamics[t=2:T+1],
        transport_vars[:SOC_HV][t] == transport_vars[:SOC_HV][t-1] - transport_vars[:D_HV][t-1] * alpha_HV + transport_vars[:H_HV_refuel][t-1])
    
    @constraint(model, HV_SOC_initial, transport_vars[:SOC_HV][1] == vehicle_params["SOC_HV_0"])
    @constraint(model, HV_SOC_final, transport_vars[:SOC_HV][T+1] == vehicle_params["SOC_HV_0"])
    @constraint(model, HV_SOC_limits[t=1:T],
        vehicle_params["SOC_HV_min"] <= transport_vars[:SOC_HV][t] <= vehicle_params["SOC_HV_max"])
    @constraint(model, HV_refuel_rate[t=1:T], transport_vars[:H_HV_refuel][t] <= vehicle_params["H_HV_max"])
    
    # EV constraints
    @constraint(model, EV_SOC_dynamics[t=2:T+1],
        transport_vars[:SOC_EV][t] == transport_vars[:SOC_EV][t-1] - transport_vars[:D_EV][t-1] * alpha_EV + 
        transport_vars[:P_EV_charge][t-1] * vehicle_params["eta_EV_charge"] - 
        transport_vars[:P_EV_V2G][t-1] / vehicle_params["eta_EV_discharge"])
    
    @constraint(model, EV_SOC_initial, transport_vars[:SOC_EV][1] == vehicle_params["SOC_EV_0"])
    @constraint(model, EV_SOC_final, transport_vars[:SOC_EV][T+1] == vehicle_params["SOC_EV_0"])
    @constraint(model, EV_SOC_limits[t=1:T],
        vehicle_params["SOC_EV_min"] <= transport_vars[:SOC_EV][t] <= vehicle_params["SOC_EV_max"])
    @constraint(model, EV_charge_rate[t=1:T], transport_vars[:P_EV_charge][t] <= vehicle_params["P_EV_max"])
    @constraint(model, EV_V2G_rate[t=1:T], transport_vars[:P_EV_V2G][t] <= vehicle_params["P_EV_max"])
end

function add_environmental_constraints(model, generation_vars, conversion_vars, env_vars, T,
                                     carbon_params, gamma_elec, gamma_fuel, renewable_mandate)
    
    # Emissions calculation
    @constraint(model, emissions_calculation[t=1:T],
        env_vars[:Emissions_total][t] == gamma_elec[t] * generation_vars[:P_grid][t] + gamma_fuel * generation_vars[:F_fuel][t])
    
    # Carbon budget constraint
    @constraint(model, carbon_budget,
        sum(env_vars[:Emissions_total][t] for t in 1:T) - sum(env_vars[:CO2_captured][t] for t in 1:T) <= carbon_params["CO2_budget"])
    
    # Carbon residual constraint
    @constraint(model, carbon_residual[t=1:T],
        env_vars[:Carbon_residual][t] >= env_vars[:Emissions_total][t] - env_vars[:CO2_captured][t])
    
    # Carbon capture constraints
    @constraint(model, carbon_capture[t=1:T],
        env_vars[:CO2_captured][t] <= carbon_params["eta_CCUS"] * generation_vars[:F_fuel][t] + 
        carbon_params["eta_CCUS_PtF"] * gamma_elec[t] * conversion_vars[:P_electrolysis_fuel][t] + 
        carbon_params["eta_CCUS_PtF"] * gamma_elec[t] * conversion_vars[:P_electrolysis_H2][t])
    
    @constraint(model, ccus_energy_consumptions[t=1:T],
        env_vars[:P_CCUS][t] >= carbon_params["eta_CCUS_loss"] * env_vars[:CO2_captured][t])
    
    # Fuel generation limit
    @constraint(model, fuel_generation_limit[t=1:T],
        generation_vars[:F_E2F][t] <= env_vars[:CO2_captured][t] * carbon_params["eta_C2F"])
    
    # Renewable energy mandate
    @constraint(model, renewable_energy_mandate,
        sum(generation_vars[:P_solar][t] + generation_vars[:P_wind][t] for t in 1:T) >= 
        renewable_mandate * sum(generation_vars[:P_grid][t] + generation_vars[:P_solar][t] + 
        generation_vars[:P_wind][t] + generation_vars[:P_CHP][t] + generation_vars[:P_fuelcell][t] for t in 1:T))
end

# Alternative model creation function with losses-based objective
function create_low_carbon_energy_system_model_losses(params::Dict)
    # Use the same model structure as the cost-based model
    model = create_low_carbon_energy_system_model(params)
    
    # Unpack necessary parameters for losses calculation
    T = params["T"]
    eta_electrolysis = params["eta_electrolysis"]
    eta_heatpump = params["eta_heatpump"]
    eta_power_to_fuel = params["eta_power_to_fuel"]
    eta_CHP = params["eta_CHP"]
    eta_fuelcell = params["eta_fuelcell"]
    eta_CH = params["eta_CH"]
    eta_DC = params["eta_DC"]
    eta_elec = params["eta_elec"]
    eta_th = params["eta_th"]
    eta_hydrogen = params["eta_hydrogen"]
    eta_EV_charge = params["eta_EV_charge"]
    eta_EV_discharge = params["eta_EV_discharge"]
    
    # Replace the objective function with a losses-based objective
    # This minimizes total system losses based on the efficiency analysis methodology
    @objective(model, Min,
        sum(
            # Energy conversion losses
            
            # Electrolysis losses (input - output in energy terms)
            (model[:P_electrolysis_H2][t] - model[:H_electrolysis][t] / eta_electrolysis) +
            (model[:P_electrolysis_fuel][t] - model[:P_electrolysis_fuel][t] * eta_power_to_fuel / eta_power_to_fuel) +
            
            # Heat pump losses (electricity input - heat output/COP)
            (model[:P_HP][t] - model[:Q_HP][t] / eta_heatpump) +
            
            # CHP losses (fuel input - electricity and heat output)
            (model[:F_CHP][t] / eta_power_to_fuel - model[:P_CHP][t] - model[:Q_CHP][t] / eta_heatpump) +
            
            # Fuel cell losses (hydrogen input - electricity output)
            (model[:H_fuelcell][t] / eta_electrolysis - model[:P_fuelcell][t]) +
            
            # Storage losses
            
            # Electricity storage losses (charging and discharging inefficiencies + decay)
            model[:P_storage_charge][t] * (1 - eta_CH) +  # Charging losses
            model[:P_storage_discharge][t] * (1/eta_DC - 1) +  # Discharging losses
            (t > 1 ? model[:E_storage][t-1] * (1 - eta_elec) : 0) +  # Storage decay losses
            
            # Thermal storage losses
            model[:Q_storage_charge][t] * (1 - eta_CH) +  # Charging losses
            model[:Q_storage_discharge][t] * (1/eta_DC - 1) +  # Discharging losses
            (t > 1 ? model[:Q_storage][t-1] * (1 - eta_th) : 0) +  # Storage decay losses
            
            # Hydrogen storage losses
            model[:H_storage_charge][t] * (1 - eta_CH) +  # Charging losses
            model[:H_storage_discharge][t] * (1/eta_DC - 1) +  # Discharging losses
            (t > 1 ? model[:H_storage][t-1] * (1 - eta_hydrogen) : 0) +  # Storage decay losses
            
            # V2G losses (EV charging and discharging inefficiencies)
            model[:P_EV_charge][t] * (1 - eta_EV_charge) +  # EV charging losses
            model[:P_EV_V2G][t] * (1/eta_EV_discharge - 1) +  # EV discharging losses
            
            # Transportation energy losses (represented as excess energy consumption above minimum)
            # Minimize deviation from efficient transportation patterns
            (model[:D_ICV][t] * params["alpha_ICV"] - 
             model[:D_ICV][t] * params["alpha_ICV"] * 0.9) +  # ICV inefficiency vs optimal
            (model[:D_EV][t] * params["alpha_EV"] - 
             model[:D_EV][t] * params["alpha_EV"] * 0.95) +  # EV inefficiency vs optimal
            (model[:D_HV][t] * params["alpha_HV"] - 
             model[:D_HV][t] * params["alpha_HV"] * 0.85)   # HV inefficiency vs optimal
            
            for t in 1:T
        )
    )
    
    return model
end

# Function to create model with selectable objective type
function create_low_carbon_energy_system_model_flexible(params::Dict, objective_type::String="cost")
    if objective_type == "cost"
        return create_low_carbon_energy_system_model(params)
    elseif objective_type == "losses"
        return create_low_carbon_energy_system_model_losses(params)
    elseif objective_type == "efficiency"
        return create_low_carbon_energy_system_model_efficiency(params)
    else
        error("Unknown objective type: $objective_type. Options are 'cost', 'losses', or 'efficiency'")
    end
end

# Additional objective function: maximize system efficiency
function create_low_carbon_energy_system_model_efficiency(params::Dict)
    # Use the same model structure as the cost-based model
    model = create_low_carbon_energy_system_model(params)
    
    # Unpack necessary parameters
    T = params["T"]
    eta_electrolysis = params["eta_electrolysis"]
    eta_heatpump = params["eta_heatpump"]
    eta_power_to_fuel = params["eta_power_to_fuel"]
    eta_fuelcell = params["eta_fuelcell"]
    
    # Replace the objective function to maximize system efficiency
    # This maximizes the ratio of useful energy output to total energy input
    @objective(model, Max,
        # Useful energy outputs (weighted by their energy value)
        sum(
            # Direct energy services
            model[:P_industry_elec][t] + model[:P_buildings_elec][t] +  # Electricity services
            model[:Q_industry_th][t] / eta_heatpump + model[:Q_buildings_th][t] / eta_heatpump +  # Heat services (normalized)
            model[:H_industry][t] / eta_electrolysis +  # Hydrogen services (normalized)
            model[:F_industry][t] / eta_power_to_fuel +  # Fuel services (normalized)
            
            # Transportation services (normalized to electricity equivalent)
            model[:D_ICV][t] * params["alpha_ICV"] / eta_power_to_fuel +  # ICV transport (normalized)
            model[:D_EV][t] * params["alpha_EV"] +  # EV transport
            model[:D_HV][t] * params["alpha_HV"] / eta_electrolysis  # HV transport (normalized)
            
            for t in 1:T
        ) 
        - 
        # Total energy inputs (to be minimized by maximizing efficiency)
        sum(
            model[:P_grid][t] +  # Grid electricity input
            model[:P_solar][t] +  # Solar input
            model[:P_wind][t] +   # Wind input
            model[:F_fuel][t] / eta_power_to_fuel  # Fuel input (normalized to electricity equivalent)
            for t in 1:T
        )
    )
    
    return model
end