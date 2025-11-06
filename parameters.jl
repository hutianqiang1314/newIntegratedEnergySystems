using Random

"""
    create_carbon_budget_scenarios()

Create different carbon budget constraint and multi-energy complementary configuration scenario parameters
"""
function create_carbon_budget_scenarios()
    # Base parameters
    base_params = create_sample_parameters()
    
    # Create scenario dictionary
    scenarios = Dict()
    
    # ===== Carbon Budget Constraint Scenarios =====
    
    # 1. Strict carbon budget constraint (60% of baseline)
    strict_budget = deepcopy(base_params)
    strict_budget["CO2_budget"] = base_params["CO2_budget"] * 0.6
    strict_budget["scenario_description"] = "Strict carbon budget constraint (60% of baseline)"
    scenarios["strict_budget"] = strict_budget
    
    # 2. Moderate carbon budget constraint (80% of baseline)
    moderate_budget = deepcopy(base_params)
    moderate_budget["CO2_budget"] = base_params["CO2_budget"] * 0.8
    moderate_budget["scenario_description"] = "Moderate carbon budget constraint (80% of baseline)"
    scenarios["moderate_budget"] = moderate_budget
    
    # 3. Relaxed carbon budget constraint (120% of baseline)
    relaxed_budget = deepcopy(base_params)
    relaxed_budget["CO2_budget"] = base_params["CO2_budget"] * 1.2
    relaxed_budget["scenario_description"] = "Relaxed carbon budget constraint (120% of baseline)"
    scenarios["relaxed_budget"] = relaxed_budget
    
    return scenarios
end

"""
    create_multi_scenario_parameters()

Create multi-scenario parameter sets, including different electrification levels, multi-energy complementary configurations and carbon budget constraint scenarios
"""
function create_multi_scenario_parameters()
    # Base parameters
    base_params = create_sample_parameters()
    
    # Create scenario dictionary
    scenarios = Dict()
    
    # ===== Electrification Level Scenarios =====
    
    # 1. High electrification scenario
    high_electrification = deepcopy(base_params)
    high_electrification["EV_ratio"] = 0.8  # 80% electric vehicle ratio
    high_electrification["HV_ratio"] = 0.15  # 15% hydrogen fuel vehicle ratio
    high_electrification["ICV_ratio"] = 0.05  # 5% fuel vehicle ratio
    # Increase corresponding infrastructure capacity
    high_electrification["P_electrolysis_max"] = 400.0  # Increase electrolysis capacity
    high_electrification["P_heatpump_max"] = 600.0      # Increase heat pump capacity
    high_electrification["scenario_description"] = "High electrification scenario"
    scenarios["high_electrification"] = high_electrification
    
    # 2. Medium electrification scenario
    medium_electrification = deepcopy(base_params)
    medium_electrification["EV_ratio"] = 0.5  # 50% electric vehicle ratio
    medium_electrification["HV_ratio"] = 0.2  # 20% hydrogen fuel vehicle ratio
    medium_electrification["ICV_ratio"] = 0.3  # 30% fuel vehicle ratio
    medium_electrification["scenario_description"] = "Medium electrification scenario"
    scenarios["medium_electrification"] = medium_electrification
    
    # 3. Low electrification scenario
    low_electrification = deepcopy(base_params)
    low_electrification["EV_ratio"] = 0.2  # 20% electric vehicle ratio
    low_electrification["HV_ratio"] = 0.1  # 10% hydrogen fuel vehicle ratio
    low_electrification["ICV_ratio"] = 0.7  # 70% fuel vehicle ratio
    # Reduce electrification infrastructure capacity
    low_electrification["P_electrolysis_max"] = 150.0   # Reduce electrolysis capacity
    low_electrification["P_heatpump_max"] = 300.0       # Reduce heat pump capacity
    low_electrification["scenario_description"] = "Low electrification scenario"
    scenarios["low_electrification"] = low_electrification
    
    # ===== Multi-energy Complementary Configuration Scenarios =====
    
    # 1. Comprehensive multi-energy complementary scenario
    full_integration = deepcopy(base_params)
    full_integration["P_heatpump_max"] = 600.0      # Large capacity heat pump
    full_integration["P_electrolysis_max"] = 500.0  # Large capacity electrolysis
    full_integration["P_CHP_max"] = 300.0           # Medium CHP capacity
    full_integration["scenario_description"] = "Comprehensive multi-energy complementary scenario"
    scenarios["full_integration"] = full_integration
    
    # 2. Electricity-heat complementary scenario only
    elec_heat_only = deepcopy(base_params)
    elec_heat_only["P_heatpump_max"] = 800.0        # Large capacity heat pump
    elec_heat_only["P_electrolysis_max"] = 100.0    # Small capacity electrolysis
    elec_heat_only["P_CHP_max"] = 200.0             # Small capacity CHP
    elec_heat_only["scenario_description"] = "Electricity-heat complementary scenario"
    scenarios["elec_heat_only"] = elec_heat_only
    
    # 3. Electricity-hydrogen complementary scenario only
    elec_hydrogen_only = deepcopy(base_params)
    elec_hydrogen_only["P_heatpump_max"] = 200.0    # Small capacity heat pump
    elec_hydrogen_only["P_electrolysis_max"] = 600.0 # Large capacity electrolysis
    elec_hydrogen_only["P_CHP_max"] = 100.0         # Small capacity CHP
    elec_hydrogen_only["scenario_description"] = "Electricity-hydrogen complementary scenario"
    scenarios["elec_hydrogen_only"] = elec_hydrogen_only
    
    # 4. No multi-energy complementary scenario
    no_integration = deepcopy(base_params)
    no_integration["P_heatpump_max"] = 100.0        # Minimum heat pump capacity
    no_integration["P_electrolysis_max"] = 50.0     # Minimum electrolysis capacity
    no_integration["P_CHP_max"] = 50.0              # Minimum CHP capacity
    no_integration["scenario_description"] = "No multi-energy complementary scenario"
    scenarios["no_integration"] = no_integration
    
    # ===== Carbon Budget Constraint Scenarios =====
    
    # Add carbon budget scenarios to multi-scenario set
    carbon_scenarios = create_carbon_budget_scenarios()
    for (name, scenario) in carbon_scenarios
        scenarios[name] = scenario
    end
    
    return scenarios
end

"""
    create_sample_parameters()

Create sample parameter set, including carbon budget constraints and multi-energy complementary mechanism parameters
"""
function create_sample_parameters()
    # Time parameters
    T = 24  # 24 hours
     

    
    # Create realistic time-varying profiles
    # ======================================
    
    # 1. Solar generation potential (follows typical daily solar curve)
    hour_of_day = collect(0:23)
    solar_factor = max.(0, sin.((hour_of_day .- 5) .* π / 14))  # Peak at noon, zero at night
    
    # Add renewable energy capacity parameters
    P_solar_rated = 500.0  # Solar rated capacity (kW)
    P_wind_rated = 500.0   # Wind rated capacity (kW)
    P_solar_max = P_solar_rated .* solar_factor  # Maximum 300 kW at peak
    # 2. Wind generation potential (more variable with some autocorrelation)
    # Start with a base pattern and add some randomness
    base_wind = [0.6, 0.5, 0.5, 0.4, 0.4, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.7, 
                 0.8, 0.9, 0.8, 0.7, 0.6, 0.5, 0.5, 0.6, 0.7, 0.8, 0.7, 0.6]
    # Add some random variations (with seed for reproducibility)
    Random.seed!(42)
    wind_variations = 0.2 .* randn(T)
    wind_factor = clamp.(base_wind .+ wind_variations, 0.1, 1.0)
    P_wind_max = P_wind_rated .* wind_factor  # Maximum 250 kW at peak
    
    # 3. Electricity price (higher during peak hours)
    # Base pattern with morning and evening peaks
    base_price = [0.10, 0.08, 0.08, 0.07, 0.07, 0.09, 0.12, 0.15, 0.18, 0.20, 
                  0.22, 0.21, 0.20, 0.19, 0.18, 0.19, 0.22, 0.25, 0.28, 0.26, 
                  0.22, 0.18, 0.15, 0.12]
    c_grid = base_price  # $/kWh for grid electricity
    
    # 4. Electricity demand profiles
    # Industry - relatively flat with slight daytime increase
    industry_pattern = [0.85, 0.80, 0.75, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.00, 
                        1.00, 1.00, 1.00, 1.00, 1.00, 0.95, 0.90, 0.90, 0.90, 0.90, 
                        0.90, 0.90, 0.85, 0.85]
    P_industry_elec_base = 500.0 .* industry_pattern
    
    # Buildings - follows typical occupancy patterns
    buildings_pattern = [0.60, 0.55, 0.50, 0.45, 0.45, 0.50, 0.60, 0.75, 0.90, 0.95, 
                         1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.85, 0.80, 0.80, 0.75, 
                         0.75, 0.70, 0.65, 0.60]
    P_buildings_elec_base = 200.0 .* buildings_pattern
    
    # 5. Thermal demand profiles
    # Industry thermal - similar to electricity but with different pattern
    industry_th_pattern = [0.80, 0.75, 0.75, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 
                           1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.95, 0.95, 0.90, 0.90, 
                           0.85, 0.85, 0.80, 0.80]
    Q_industry_th_base = 300.0 .* industry_th_pattern
    
    # Buildings thermal - higher in morning and evening
    buildings_th_pattern = [0.65, 0.60, 0.55, 0.50, 0.55, 0.65, 0.75, 0.85, 0.90, 0.85, 
                            0.80, 0.75, 0.70, 0.70, 0.75, 0.80, 0.85, 0.95, 1.00, 0.95, 
                            0.90, 0.85, 0.75, 0.70]
    Q_buildings_th_base = 250.0 .* buildings_th_pattern
    
    # 6. Transportation demand (higher during commuting hours)
    transport_pattern = [0.30, 0.20, 0.15, 0.10, 0.15, 0.40, 0.70, 1.00, 0.90, 0.70, 
                         0.60, 0.65, 0.70, 0.65, 0.60, 0.70, 0.90, 1.00, 0.80, 0.60, 
                         0.50, 0.45, 0.40, 0.35]
    D_total = 1000.0 .* transport_pattern
    
    # 7. Hydrogen industry demand (relatively constant)
    H_industry_base = 50.0 .* (0.9 .+ 0.2 .* rand(T))
    
    # 8. Fuel industry demand (relatively constant)
    F_industry_base = 100.0 .* (0.9 .+ 0.2 .* rand(T))
    
    # Carbon intensity parameters
    # Time-varying carbon intensity of grid electricity (lower during high renewable periods)
    gamma_elec = 0.5 .* (1.0 .- 0.3 .* solar_factor)  # Lower during solar hours
    gamma_fuel = 1.0  # kg CO2/kWh for fuels
    
    # Cost parameters
    c_solar = 0.08  # $/kWh for solar
    c_wind = 0.07  # $/kWh for wind
    c_fuel = 0.6  # $/kWh for fuel
    c_cert = 0.05  # $/kWh for green certificates
    lambda = 0.1  # $/kg CO2 for carbon penalty
    
    # Transportation parameters
    alpha_ICV = 0.6  # kWh/km for ICVs
    alpha_EV = 0.2  # kWh/km for EVs
    alpha_HV = 0.3  # kWh/km for HVs
    
    # Storage parameters
    E_storage_0 = 100.0  # Initial electricity storage (kWh)
    Q_storage_0 = 100.0  # Initial thermal storage (kWh)
    H_storage_0 = 100.0  # Initial hydrogen storage (kWh)
    
    E_storage_max = 500.0  # Maximum electricity storage (kWh)
    Q_storage_max = 500.0  # Maximum thermal storage (kWh)
    H_storage_max = 500.0  # Maximum hydrogen storage (kWh)
    
    E_storage_min = 50.0  # Minimum electricity storage (kWh)
    Q_storage_min = 50.0  # Minimum thermal storage (kWh)
    H_storage_min = 50.0  # Minimum hydrogen storage (kWh)
    
    P_storage_max = 100.0  # Maximum electricity charging/discharging rate (kW)
    Q_storage_max_rate = 100.0  # Maximum thermal charging/discharging rate (kW)
    H_storage_max_rate = 100.0  # Maximum hydrogen charging/discharging rate (kW)
    
    # Emissions parameters
    CO2_budget = 6000.0  # Total allowable carbon emissions (kg)
    eta_CH = 0.95  # Charging efficiency
    eta_DC = 0.95  # Discharging efficiency
    eta_CCUS = 0.9  # Efficiency of carbon capture
    eta_CCUS_PtF = 0.6  # Efficiency of carbon capture for power-to-fuel
    eta_C2F = 0.2  # Efficiency of carbon capture for power-to-fuel conversion
    eta_CCUS_loss = 0.2 # Losses in carbon capture and storage
    # Conversion efficiencies
    eta_electrolysis = 0.6  # Efficiency of electrolysis
    eta_CHP = 0.75  # Total efficiency of CHP
    eta_CHP_elec = 0.35  # Electrical efficiency of CHP
    eta_CHP_th = 0.4  # Thermal efficiency of CHP
    eta_heatpump = 3.0  # COP for heat pumps
    eta_fuelcell = 0.6  # Efficiency of fuel cells
    eta_power_to_fuel = 0.3  # Efficiency of power-to-fuel conversion
    eta_wasteheat = 0.3  # Efficiency of waste heat recovery
    
    # Storage decay rates
    eta_elec = 0.98  # Electricity storage decay rate
    eta_th = 0.9  # Thermal storage decay rate
    eta_hydrogen = 0.99  # Hydrogen storage decay rate
    
    # Transportation demand boundaries
    D_ICV_min = 0.0  # Minimum ICV transportation demand
    D_ICV_max = 1000.0  # Maximum ICV transportation demand
    D_EV_min = 0.0  # Minimum EV transportation demand
    D_EV_max = 1000.0  # Maximum EV transportation demand
    D_HV_min = 0.0  # Minimum HV transportation demand
    D_HV_max = 1000.0  # Maximum HV transportation demand
    
    # Initial transportation energy status
    D_ICV_0 = 300.0  # Initial ICV transportation demand
    D_EV_0 = 300.0  # Initial EV transportation demand
    D_HV_0 = 300.0  # Initial HV transportation demand
    
    # Renewable mandate percentage
    renewable_mandate = 0.01  # 30% renewable energy mandate
    
    # V2G parameters
    SOC_EV_0 = 300.0  # Initial state of charge for EV fleet
    SOC_EV_min = 100.0  # Minimum state of charge for EV fleet
    SOC_EV_max = 500.0  # Maximum state of charge for EV fleet
    P_EV_max = 100.0  # Maximum charging/discharging rate for EV fleet
    eta_EV_charge = 0.95  # EV charging efficiency
    eta_EV_discharge = 0.9  # EV discharging efficiency
    
    # Peak hours for V2G incentives (9AM-6PM)
    peak_hours = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0]
    V2G_incentive = 0.05  # Incentive payment for V2G services
    
    # Parameters for ICV and HV energy dynamics
    SOC_ICV_0 = 30000.0  # Initial state of charge for ICV fleet
    SOC_ICV_min = 5000.0  # Minimum state of charge for ICV fleet
    SOC_ICV_max = 50000.0  # Maximum state of charge for ICV fleet
    F_ICV_max = 5000.0  # Maximum refueling rate for ICV fleet
    
    SOC_HV_0 = 5000.0  # Initial state of charge for HV fleet
    SOC_HV_min = 1000.0  # Minimum state of charge for HV fleet
    SOC_HV_max = 10000.0  # Maximum state of charge for HV fleet
    H_HV_max = 1000.0  # Maximum refueling rate for HV fleet
    
    P_fuelcell_max = 100.0  # Maximum output for fuel cell (kW)
    
    # Add carbon budget constraint explicit characterization parameters
    carbon_budget_type = "cumulative"  # Cumulative carbon budget type: "cumulative", "intensity", "reduction"
    carbon_intensity_target = 0.3      # Target carbon intensity (kg CO2/kWh)
    carbon_reduction_target = 0.4      # Emission reduction target relative to baseline
    carbon_price = 50.0                # Carbon price ($/ton CO2)
    
    # Add multi-energy complementary parameters
    multi_energy_integration = true    # Whether to enable multi-energy complementary
    elec_heat_integration = true       # Whether to enable electricity-heat complementary
    elec_hydrogen_integration = true   # Whether to enable electricity-hydrogen complementary
    heat_power_integration = true      # Whether to enable heat-electricity complementary
    
    # Add vehicle fleet ratio parameters
    ICV_ratio = 0.6                    # Internal combustion vehicle ratio
    EV_ratio = 0.3                     # Electric vehicle ratio
    HV_ratio = 0.1                     # Hydrogen vehicle ratio
    
    # Component maximum capacities - UPDATED: Remove redundant parameters
    P_heatpump_max = 500.0         # Maximum heat pump capacity (MW)
    P_electrolysis_max = 300.0     # Maximum electrolysis capacity (MW)
    P_CHP_max = 400.0              # Maximum CHP capacity (MW)
    
    # Return all parameters as a dictionary
    return Dict(
        "T" => T,
        "gamma_elec" => gamma_elec,
        "gamma_fuel" => gamma_fuel,
        "c_cert" => c_cert,
        "lambda" => lambda,
        "c_grid" => c_grid,
        "c_solar" => c_solar,
        "c_wind" => c_wind,
        "c_fuel" => c_fuel,
        "D_total" => D_total,
        "alpha_ICV" => alpha_ICV,
        "alpha_EV" => alpha_EV,
        "alpha_HV" => alpha_HV,
        
        # Storage parameters
        "E_storage_0" => E_storage_0,
        "Q_storage_0" => Q_storage_0,
        "H_storage_0" => H_storage_0,
        "E_storage_max" => E_storage_max,
        "Q_storage_max" => Q_storage_max,
        "H_storage_max" => H_storage_max,
        "E_storage_min" => E_storage_min,
        "Q_storage_min" => Q_storage_min,
        "H_storage_min" => H_storage_min,
        "P_storage_max" => P_storage_max,
        "Q_storage_max_rate" => Q_storage_max_rate,
        "H_storage_max_rate" => H_storage_max_rate,
        
        # Emissions parameters
        "CO2_budget" => CO2_budget,
        "eta_CH" => eta_CH,
        "eta_DC" => eta_DC,
        "eta_CCUS" => eta_CCUS,
        "eta_CCUS_PtF" => eta_CCUS_PtF,
        "eta_C2F" => eta_C2F,
        "eta_CCUS_loss" => eta_CCUS_loss,
        # Conversion efficiencies
        "eta_electrolysis" => eta_electrolysis,
        "eta_CHP" => eta_CHP,
        "eta_CHP_elec" => eta_CHP_elec,
        "eta_CHP_th" => eta_CHP_th,
        "eta_heatpump" => eta_heatpump,
        "eta_fuelcell" => eta_fuelcell,
        "eta_power_to_fuel" => eta_power_to_fuel,
        "eta_wasteheat" => eta_wasteheat,
        
        # Storage decay rates
        "eta_elec" => eta_elec,
        "eta_th" => eta_th,
        "eta_hydrogen" => eta_hydrogen,
        
        # Base demand profiles
        "P_industry_elec_base" => P_industry_elec_base,
        "Q_industry_th_base" => Q_industry_th_base,
        "H_industry_base" => H_industry_base,
        "F_industry_base" => F_industry_base,
        "P_buildings_elec_base" => P_buildings_elec_base,
        "Q_buildings_th_base" => Q_buildings_th_base,
        
        # Transportation demand boundaries
        "D_ICV_min" => D_ICV_min,
        "D_ICV_max" => D_ICV_max,
        "D_EV_min" => D_EV_min,
        "D_EV_max" => D_EV_max,
        "D_HV_min" => D_HV_min,
        "D_HV_max" => D_HV_max,
        
        # Initial transportation energy status
        "D_ICV_0" => D_ICV_0,
        "D_EV_0" => D_EV_0,
        "D_HV_0" => D_HV_0,
        
        # Renewable mandate percentage
        "renewable_mandate" => renewable_mandate,
        
        # Maximum output for renewables
        "P_solar_max" => P_solar_max,
        "P_wind_max" => P_wind_max,
        
        # Maximum fuel cell capacity
        "P_fuelcell_max" => P_fuelcell_max,
        
        # V2G parameters
        "SOC_EV_0" => SOC_EV_0,
        "SOC_EV_min" => SOC_EV_min,
        "SOC_EV_max" => SOC_EV_max,
        "P_EV_max" => P_EV_max,
        "eta_EV_charge" => eta_EV_charge,
        "eta_EV_discharge" => eta_EV_discharge,
        "peak_hours" => peak_hours,
        "V2G_incentive" => V2G_incentive,
        
        # ICV parameters
        "SOC_ICV_0" => SOC_ICV_0,
        "SOC_ICV_min" => SOC_ICV_min,
        "SOC_ICV_max" => SOC_ICV_max,
        "F_ICV_max" => F_ICV_max,
        
        # HV parameters
        "SOC_HV_0" => SOC_HV_0,
        "SOC_HV_min" => SOC_HV_min,
        "SOC_HV_max" => SOC_HV_max,
        "H_HV_max" => H_HV_max,
        
        # Carbon budget constraint explicit characterization parameters
        "carbon_budget_type" => carbon_budget_type,
        "carbon_intensity_target" => carbon_intensity_target,
        "carbon_reduction_target" => carbon_reduction_target,
        "carbon_price" => carbon_price,
        
        # Multi-energy complementary parameters
        "multi_energy_integration" => multi_energy_integration,
        "elec_heat_integration" => elec_heat_integration,
        "elec_hydrogen_integration" => elec_hydrogen_integration,
        "heat_power_integration" => heat_power_integration,
        
        # Vehicle fleet ratio parameters
        "ICV_ratio" => ICV_ratio,
        "EV_ratio" => EV_ratio,
        "HV_ratio" => HV_ratio,

        # Renewable capacity parameters (use rated values as capacity limits)
        "P_solar_rated" => P_solar_rated,
        "P_wind_rated" => P_wind_rated,
        
        # Component maximum capacities (non-redundant parameters only)
        "P_heatpump_max" => P_heatpump_max,
        "P_electrolysis_max" => P_electrolysis_max,
        "P_CHP_max" => P_CHP_max
    )
end




function create_weekly_sample_parameters()
    # Time parameters
    T = 168  # 168 hours (1 week)

    # Initialize parameter dictionary
    params = Dict{String, Any}()

    # Add time parameters
    params["T"] = T

    
    # Create realistic time-varying profiles
    # ======================================
    
    # 1. Solar generation potential (follows typical daily solar curve)
    hour_of_day = collect(0:23)
    daily_solar_factor = max.(0, sin.((hour_of_day .- 5) .* π / 14))  # Peak at noon, zero at night
    solar_factor = repeat(daily_solar_factor, 7)  # Repeat for 7 days
    
    # Add renewable energy capacity parameters
    P_solar_rated = 500.0  # Solar rated capacity (kW)
    P_wind_rated = 500.0   # Wind rated capacity (kW)
    P_solar_max = P_solar_rated .* solar_factor  # Maximum 300 kW at peak
    
    # 2. Wind generation potential (more variable with some autocorrelation)
    # Start with a base pattern and add some randomness
    daily_base_wind = [0.6, 0.5, 0.5, 0.4, 0.4, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.7, 
                       0.8, 0.9, 0.8, 0.7, 0.6, 0.5, 0.5, 0.6, 0.7, 0.8, 0.7, 0.6]
    base_wind = repeat(daily_base_wind, 7)  # Repeat for 7 days
    # Add some random variations (with seed for reproducibility)
    Random.seed!(42)
    wind_variations = 0.2 .* randn(T)
    wind_factor = clamp.(base_wind .+ wind_variations, 0.1, 1.0)
    P_wind_max = P_wind_rated .* wind_factor  # Maximum 250 kW at peak
    
    # 3. Electricity price (higher during peak hours)
    # Base pattern with morning and evening peaks
    daily_base_price = [0.10, 0.08, 0.08, 0.07, 0.07, 0.09, 0.12, 0.15, 0.18, 0.20, 
                        0.22, 0.21, 0.20, 0.19, 0.18, 0.19, 0.22, 0.25, 0.28, 0.26, 
                        0.22, 0.18, 0.15, 0.12]
    c_grid = repeat(daily_base_price, 7)  # $/kWh for grid electricity
    
    # 4. Electricity demand profiles
    # Industry - relatively flat with slight daytime increase
    daily_industry_pattern = [0.85, 0.80, 0.75, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.00, 
                              1.00, 1.00, 1.00, 1.00, 1.00, 0.95, 0.90, 0.90, 0.90, 0.90, 
                              0.90, 0.90, 0.85, 0.85]
    industry_pattern = repeat(daily_industry_pattern, 7)
    P_industry_elec_base = 500.0 .* industry_pattern
    
    # Buildings - follows typical occupancy patterns
    daily_buildings_pattern = [0.60, 0.55, 0.50, 0.45, 0.45, 0.50, 0.60, 0.75, 0.90, 0.95, 
                               1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.85, 0.80, 0.80, 0.75, 
                               0.75, 0.70, 0.65, 0.60]
    buildings_pattern = repeat(daily_buildings_pattern, 7)
    P_buildings_elec_base = 200.0 .* buildings_pattern
    
    # 5. Thermal demand profiles
    # Industry thermal - similar to electricity but with different pattern
    daily_industry_th_pattern = [0.80, 0.75, 0.75, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 
                                 1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.95, 0.95, 0.90, 0.90, 
                                 0.85, 0.85, 0.80, 0.80]
    industry_th_pattern = repeat(daily_industry_th_pattern, 7)
    Q_industry_th_base = 300.0 .* industry_th_pattern
    
    # Buildings thermal - higher in morning and evening
    daily_buildings_th_pattern = [0.65, 0.60, 0.55, 0.50, 0.55, 0.65, 0.75, 0.85, 0.90, 0.85, 
                                  0.80, 0.75, 0.70, 0.70, 0.75, 0.80, 0.85, 0.95, 1.00, 0.95, 
                                  0.90, 0.85, 0.75, 0.70]
    buildings_th_pattern = repeat(daily_buildings_th_pattern, 7)
    Q_buildings_th_base = 250.0 .* buildings_th_pattern
    
    # 6. Transportation demand (higher during commuting hours)
    daily_transport_pattern = [0.30, 0.20, 0.15, 0.10, 0.15, 0.40, 0.70, 1.00, 0.90, 0.70, 
                               0.60, 0.65, 0.70, 0.65, 0.60, 0.70, 0.90, 1.00, 0.80, 0.60, 
                               0.50, 0.45, 0.40, 0.35]
    transport_pattern = repeat(daily_transport_pattern, 7)
    D_total = 1000.0 .* transport_pattern
    
    # 7. Hydrogen industry demand (relatively constant)
    H_industry_base = 50.0 .* (0.9 .+ 0.2 .* rand(T))
    
    # 8. Fuel industry demand (relatively constant)
    F_industry_base = 100.0 .* (0.9 .+ 0.2 .* rand(T))
    
    # Carbon intensity parameters
    # Time-varying carbon intensity of grid electricity (lower during high renewable periods)
    gamma_elec = 0.5 .* (1.0 .- 0.3 .* solar_factor)  # Lower during solar hours
    gamma_fuel = 1.0  # kg CO2/kWh for fuels
    
    # Cost parameters
    c_solar = 0.08  # $/kWh for solar
    c_wind = 0.07  # $/kWh for wind
    c_fuel = 0.6  # $/kWh for fuel
    c_cert = 0.05  # $/kWh for green certificates
    lambda = 0.1  # $/kg CO2 for carbon penalty
    
    # Transportation parameters
    alpha_ICV = 0.6  # kWh/km for ICVs
    alpha_EV = 0.2  # kWh/km for EVs
    alpha_HV = 0.3  # kWh/km for HVs
    
    # Storage parameters
    E_storage_0 = 100.0  # Initial electricity storage (kWh)
    Q_storage_0 = 100.0  # Initial thermal storage (kWh)
    H_storage_0 = 100.0  # Initial hydrogen storage (kWh)
    
    E_storage_max = 500.0  # Maximum electricity storage (kWh)
    Q_storage_max = 500.0  # Maximum thermal storage (kWh)
    H_storage_max = 500.0  # Maximum hydrogen storage (kWh)
    
    E_storage_min = 50.0  # Minimum electricity storage (kWh)
    Q_storage_min = 50.0  # Minimum thermal storage (kWh)
    H_storage_min = 50.0  # Minimum hydrogen storage (kWh)
    
    P_storage_max = 100.0  # Maximum electricity charging/discharging rate (kW)
    Q_storage_max_rate = 100.0  # Maximum thermal charging/discharging rate (kW)
    H_storage_max_rate = 100.0  # Maximum hydrogen charging/discharging rate (kW)
    
    # Emissions parameters
    CO2_budget = 6000.0  # Total allowable carbon emissions (kg)
    eta_CH = 0.95  # Charging efficiency
    eta_DC = 0.95  # Discharging efficiency
    eta_CCUS = 0.9  # Efficiency of carbon capture
    eta_CCUS_PtF = 0.6  # Efficiency of carbon capture for power-to-fuel
    eta_C2F = 0.2  # Efficiency of carbon capture for power-to-fuel conversion
    eta_CCUS_loss = 0.2 # Losses in carbon capture and storage
    # Conversion efficiencies
    eta_electrolysis = 0.6  # Efficiency of electrolysis
    eta_CHP = 0.75  # Total efficiency of CHP
    eta_CHP_elec = 0.35  # Electrical efficiency of CHP
    eta_CHP_th = 0.4  # Thermal efficiency of CHP
    eta_heatpump = 3.0  # COP for heat pumps
    eta_fuelcell = 0.6  # Efficiency of fuel cells
    eta_power_to_fuel = 0.3  # Efficiency of power-to-fuel conversion
    eta_wasteheat = 0.3  # Efficiency of waste heat recovery
    
    # Storage decay rates
    eta_elec = 0.98  # Electricity storage decay rate
    eta_th = 0.9  # Thermal storage decay rate
    eta_hydrogen = 0.99  # Hydrogen storage decay rate
    
    # Transportation demand boundaries
    D_ICV_min = 0.0  # Minimum ICV transportation demand
    D_ICV_max = 1000.0  # Maximum ICV transportation demand
    D_EV_min = 0.0  # Minimum EV transportation demand
    D_EV_max = 1000.0  # Maximum EV transportation demand
    D_HV_min = 0.0  # Minimum HV transportation demand
    D_HV_max = 1000.0  # Maximum HV transportation demand
    
    # Initial transportation energy status
    D_ICV_0 = 300.0  # Initial ICV transportation demand
    D_EV_0 = 300.0  # Initial EV transportation demand
    D_HV_0 = 300.0  # Initial HV transportation demand
    
    # Renewable mandate percentage
    renewable_mandate = 0.01  # 30% renewable energy mandate
    
    # V2G parameters
    SOC_EV_0 = 300.0  # Initial state of charge for EV fleet
    SOC_EV_min = 100.0  # Minimum state of charge for EV fleet
    SOC_EV_max = 500.0  # Maximum state of charge for EV fleet
    P_EV_max = 100.0  # Maximum charging/discharging rate for EV fleet
    eta_EV_charge = 0.95  # EV charging efficiency
    eta_EV_discharge = 0.9  # EV discharging efficiency
    
    # Peak hours for V2G incentives (9AM-6PM)
    daily_peak_hours = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0]
    peak_hours = repeat(daily_peak_hours, 7)
    V2G_incentive = 0.05  # Incentive payment for V2G services
    
    # Parameters for ICV and HV energy dynamics
    SOC_ICV_0 = 30000.0  # Initial state of charge for ICV fleet
    SOC_ICV_min = 5000.0  # Minimum state of charge for ICV fleet
    SOC_ICV_max = 50000.0  # Maximum state of charge for ICV fleet
    F_ICV_max = 5000.0  # Maximum refueling rate for ICV fleet
    
    SOC_HV_0 = 5000.0  # Initial state of charge for HV fleet
    SOC_HV_min = 1000.0  # Minimum state of charge for HV fleet
    SOC_HV_max = 10000.0  # Maximum state of charge for HV fleet
    H_HV_max = 1000.0  # Maximum refueling rate for HV fleet
    
    P_fuelcell_max = 100.0  # Maximum output for fuel cell (kW)
    
    # Add carbon budget constraint explicit characterization parameters
    carbon_budget_type = "cumulative"  # Cumulative carbon budget type: "cumulative", "intensity", "reduction"
    carbon_intensity_target = 0.3      # Target carbon intensity (kg CO2/kWh)
    carbon_reduction_target = 0.4      # Emission reduction target relative to baseline
    carbon_price = 50.0                # Carbon price ($/ton CO2)
    
    # Add multi-energy complementary parameters
    multi_energy_integration = true    # Whether to enable multi-energy complementary
    elec_heat_integration = true       # Whether to enable electricity-heat complementary
    elec_hydrogen_integration = true   # Whether to enable electricity-hydrogen complementary
    heat_power_integration = true      # Whether to enable heat-electricity complementary
    
    # Add vehicle fleet ratio parameters
    ICV_ratio = 0.6                    # Internal combustion vehicle ratio
    EV_ratio = 0.3                     # Electric vehicle ratio
    HV_ratio = 0.1                     # Hydrogen vehicle ratio
    
    # Component maximum capacities - UPDATED: Remove redundant parameters
    P_heatpump_max = 500.0         # Maximum heat pump capacity (MW)
    P_electrolysis_max = 300.0     # Maximum electrolysis capacity (MW)
    P_CHP_max = 400.0              # Maximum CHP capacity (MW)
    
    # Return all parameters as a dictionary
    return Dict(
        "T" => T,
        "gamma_elec" => gamma_elec,
        "gamma_fuel" => gamma_fuel,
        "c_cert" => c_cert,
        "lambda" => lambda,
        "c_grid" => c_grid,
        "c_solar" => c_solar,
        "c_wind" => c_wind,
        "c_fuel" => c_fuel,
        "D_total" => D_total,
        "alpha_ICV" => alpha_ICV,
        "alpha_EV" => alpha_EV,
        "alpha_HV" => alpha_HV,
        
        # Storage parameters
        "E_storage_0" => E_storage_0,
        "Q_storage_0" => Q_storage_0,
        "H_storage_0" => H_storage_0,
        "E_storage_max" => E_storage_max,
        "Q_storage_max" => Q_storage_max,
        "H_storage_max" => H_storage_max,
        "E_storage_min" => E_storage_min,
        "Q_storage_min" => Q_storage_min,
        "H_storage_min" => H_storage_min,
        "P_storage_max" => P_storage_max,
        "Q_storage_max_rate" => Q_storage_max_rate,
        "H_storage_max_rate" => H_storage_max_rate,
        
        # Emissions parameters
        "CO2_budget" => CO2_budget,
        "eta_CH" => eta_CH,
        "eta_DC" => eta_DC,
        "eta_CCUS" => eta_CCUS,
        "eta_CCUS_PtF" => eta_CCUS_PtF,
        "eta_C2F" => eta_C2F,
        "eta_CCUS_loss" => eta_CCUS_loss,
        # Conversion efficiencies
        "eta_electrolysis" => eta_electrolysis,
        "eta_CHP" => eta_CHP,
        "eta_CHP_elec" => eta_CHP_elec,
        "eta_CHP_th" => eta_CHP_th,
        "eta_heatpump" => eta_heatpump,
        "eta_fuelcell" => eta_fuelcell,
        "eta_power_to_fuel" => eta_power_to_fuel,
        "eta_wasteheat" => eta_wasteheat,
        
        # Storage decay rates
        "eta_elec" => eta_elec,
        "eta_th" => eta_th,
        "eta_hydrogen" => eta_hydrogen,
        
        # Base demand profiles
        "P_industry_elec_base" => P_industry_elec_base,
        "Q_industry_th_base" => Q_industry_th_base,
        "H_industry_base" => H_industry_base,
        "F_industry_base" => F_industry_base,
        "P_buildings_elec_base" => P_buildings_elec_base,
        "Q_buildings_th_base" => Q_buildings_th_base,
        
        # Transportation demand boundaries
        "D_ICV_min" => D_ICV_min,
        "D_ICV_max" => D_ICV_max,
        "D_EV_min" => D_EV_min,
        "D_EV_max" => D_EV_max,
        "D_HV_min" => D_HV_min,
        "D_HV_max" => D_HV_max,
        
        # Initial transportation energy status
        "D_ICV_0" => D_ICV_0,
        "D_EV_0" => D_EV_0,
        "D_HV_0" => D_HV_0,
        
        # Renewable mandate percentage
        "renewable_mandate" => renewable_mandate,
        
        # Maximum output for renewables
        "P_solar_max" => P_solar_max,
        "P_wind_max" => P_wind_max,
        
        # Maximum fuel cell capacity
        "P_fuelcell_max" => P_fuelcell_max,
        
        # V2G parameters
        "SOC_EV_0" => SOC_EV_0,
        "SOC_EV_min" => SOC_EV_min,
        "SOC_EV_max" => SOC_EV_max,
        "P_EV_max" => P_EV_max,
        "eta_EV_charge" => eta_EV_charge,
        "eta_EV_discharge" => eta_EV_discharge,
        "peak_hours" => peak_hours,
        "V2G_incentive" => V2G_incentive,
        
        # ICV parameters
        "SOC_ICV_0" => SOC_ICV_0,
        "SOC_ICV_min" => SOC_ICV_min,
        "SOC_ICV_max" => SOC_ICV_max,
        "F_ICV_max" => F_ICV_max,
        
        # HV parameters
        "SOC_HV_0" => SOC_HV_0,
        "SOC_HV_min" => SOC_HV_min,
        "SOC_HV_max" => SOC_HV_max,
        "H_HV_max" => H_HV_max,
        
        # Carbon budget constraint explicit characterization parameters
        "carbon_budget_type" => carbon_budget_type,
        "carbon_intensity_target" => carbon_intensity_target,
        "carbon_reduction_target" => carbon_reduction_target,
        "carbon_price" => carbon_price,
        
        # Multi-energy complementary parameters
        "multi_energy_integration" => multi_energy_integration,
        "elec_heat_integration" => elec_heat_integration,
        "elec_hydrogen_integration" => elec_hydrogen_integration,
        "heat_power_integration" => heat_power_integration,
        
        # Vehicle fleet ratio parameters
        "ICV_ratio" => ICV_ratio,
        "EV_ratio" => EV_ratio,
        "HV_ratio" => HV_ratio,

        # Renewable capacity parameters (use rated values as capacity limits)
        "P_solar_rated" => P_solar_rated,
        "P_wind_rated" => P_wind_rated,
        
        # Component maximum capacities (non-redundant parameters only)
        "P_heatpump_max" => P_heatpump_max,
        "P_electrolysis_max" => P_electrolysis_max,
        "P_CHP_max" => P_CHP_max
    )
end
