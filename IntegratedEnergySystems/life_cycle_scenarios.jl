using Random
using DataFrames
using Dates
using Statistics
using CSV

"""
    generate_lifecycle_scenarios(; years=20, typical_days=6, hours_per_day=24)

Generate full life cycle scenarios covering multiple time scales:
- Short-term: Hourly/daily operational parameters
- Medium-term: Annual/seasonal strategic parameters  
- Long-term: Multi-year investment and technology parameters

Parameters:
- years: Total simulation years, default 20 years
- typical_days: Number of typical days per year, default 6
- hours_per_day: Hours per day, default 24 hours

Returns:
- Dictionary containing multi-time-scale scenario data
"""
function generate_lifecycle_scenarios(; years=20, typical_days=6, hours_per_day=24)
    # Set random seed for reproducibility
    Random.seed!(42)
    
    # Create scenario container
    scenarios = Dict()
    
    # ===== 1. Time Structure Setup =====
    time_structure = Dict(
        "years" => years,
        "typical_days" => typical_days,
        "hours_per_day" => hours_per_day,
        "total_periods" => years * typical_days * hours_per_day
    )
    
    # Create time indices
    time_indices = Dict()
    time_indices["year_indices"] = collect(1:years)
    
    # Typical day descriptions
    typical_day_types = [
        "winter_weekday", "winter_weekend",
        "summer_weekday", "summer_weekend", 
        "spring_autumn_weekday", "spring_autumn_weekend"
    ]
    time_indices["typical_day_types"] = typical_day_types[1:typical_days]
    time_indices["hour_indices"] = collect(1:hours_per_day)
    
    scenarios["time_structure"] = time_structure
    scenarios["time_indices"] = time_indices
    
    # ===== 2. SHORT-TERM FACTORS (Hourly/Daily) =====
    short_term_factors = Dict()
    
    # 2.1 Solar generation patterns (hourly)
    solar_patterns = Dict()
    for day_type in time_indices["typical_day_types"]
        season = split(day_type, "_")[1]
        if season == "winter"
            solar_patterns[day_type] = [0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.05, 0.15, 0.30, 0.45, 
                                       0.60, 0.70, 0.65, 0.55, 0.40, 0.25, 0.10, 0.00, 0.00, 0.00, 
                                       0.00, 0.00, 0.00, 0.00]
        elseif season == "summer"
            solar_patterns[day_type] = [0.00, 0.00, 0.00, 0.00, 0.05, 0.15, 0.30, 0.45, 0.60, 0.75, 
                                       0.85, 0.95, 1.00, 0.95, 0.85, 0.70, 0.55, 0.40, 0.25, 0.10, 
                                       0.00, 0.00, 0.00, 0.00]
        else # spring_autumn
            solar_patterns[day_type] = [0.00, 0.00, 0.00, 0.00, 0.00, 0.10, 0.25, 0.40, 0.55, 0.70, 
                                       0.80, 0.90, 0.85, 0.75, 0.65, 0.50, 0.35, 0.20, 0.05, 0.00, 
                                       0.00, 0.00, 0.00, 0.00]
        end
    end
    short_term_factors["solar_patterns"] = solar_patterns
    
    # 2.2 Wind generation patterns (hourly with seasonal variation)
    wind_patterns = Dict()
    for day_type in time_indices["typical_day_types"]
        season = split(day_type, "_")[1]
        if season == "winter"
            wind_patterns[day_type] = [0.70, 0.75, 0.80, 0.75, 0.70, 0.65, 0.60, 0.55, 0.50, 0.55, 
                                      0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 0.95, 
                                      0.90, 0.85, 0.80, 0.75]
        elseif season == "summer"
            wind_patterns[day_type] = [0.40, 0.35, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 
                                      0.70, 0.75, 0.80, 0.85, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 
                                      0.60, 0.55, 0.50, 0.45]
        else # spring_autumn
            wind_patterns[day_type] = [0.55, 0.50, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 
                                      0.85, 0.90, 0.95, 1.00, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 
                                      0.65, 0.60, 0.55, 0.50]
        end
    end
    short_term_factors["wind_patterns"] = wind_patterns
    
    # 2.3 Electricity price patterns (hourly with day type variation)
    electricity_price_patterns = Dict()
    for day_type in time_indices["typical_day_types"]
        day_category = split(day_type, "_")[2]
        if day_category == "weekday"
            electricity_price_patterns[day_type] = [0.07, 0.06, 0.06, 0.06, 0.07, 0.10, 0.15, 0.20, 0.25, 0.20, 
                                                   0.15, 0.20, 0.25, 0.20, 0.15, 0.20, 0.25, 0.30, 0.25, 0.20, 
                                                   0.15, 0.10, 0.08, 0.07]
        else # weekend
            electricity_price_patterns[day_type] = [0.06, 0.05, 0.05, 0.05, 0.06, 0.07, 0.10, 0.12, 0.15, 0.18, 
                                                   0.20, 0.18, 0.15, 0.18, 0.20, 0.18, 0.15, 0.12, 0.10, 0.08, 
                                                   0.07, 0.06, 0.06, 0.06]
        end
    end
    short_term_factors["electricity_price_patterns"] = electricity_price_patterns
    
    # 2.4 Electricity demand profiles (hourly by sector)
    electricity_demand_patterns = Dict()
    
    # Industry electricity demand - relatively flat
    industry_elec_pattern = [0.85, 0.80, 0.75, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.00, 
                            1.00, 1.00, 1.00, 1.00, 1.00, 0.95, 0.90, 0.90, 0.90, 0.90, 
                            0.90, 0.90, 0.85, 0.85]
    
    # Buildings electricity demand - follows occupancy
    buildings_elec_pattern = [0.60, 0.55, 0.50, 0.45, 0.45, 0.50, 0.60, 0.75, 0.90, 0.95, 
                             1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.85, 0.80, 0.80, 0.75, 
                             0.75, 0.70, 0.65, 0.60]
    
    electricity_demand_patterns["industry"] = industry_elec_pattern
    electricity_demand_patterns["buildings"] = buildings_elec_pattern
    short_term_factors["electricity_demand_patterns"] = electricity_demand_patterns
    
    # 2.5 Thermal demand profiles (hourly by sector)
    thermal_demand_patterns = Dict()
    
    # Industry thermal demand
    industry_th_pattern = [0.80, 0.75, 0.75, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 
                          1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.95, 0.95, 0.90, 0.90, 
                          0.85, 0.85, 0.80, 0.80]
    
    # Buildings thermal demand - higher in morning and evening
    buildings_th_pattern = [0.65, 0.60, 0.55, 0.50, 0.55, 0.65, 0.75, 0.85, 0.90, 0.85, 
                           0.80, 0.75, 0.70, 0.70, 0.75, 0.80, 0.85, 0.95, 1.00, 0.95, 
                           0.90, 0.85, 0.75, 0.70]
    
    thermal_demand_patterns["industry"] = industry_th_pattern
    thermal_demand_patterns["buildings"] = buildings_th_pattern
    short_term_factors["thermal_demand_patterns"] = thermal_demand_patterns
    
    # 2.6 Transportation demand patterns (hourly with commuting peaks)
    transport_pattern = [0.30, 0.20, 0.15, 0.10, 0.15, 0.40, 0.70, 1.00, 0.90, 0.70, 
                        0.60, 0.65, 0.70, 0.65, 0.60, 0.70, 0.90, 1.00, 0.80, 0.60, 
                        0.50, 0.45, 0.40, 0.35]
    short_term_factors["transportation_pattern"] = transport_pattern
    
    # 2.7 Hydrogen industry demand (relatively constant with small hourly variations)
    hydrogen_industry_pattern = 0.9 .+ 0.2 .* rand(hours_per_day)
    short_term_factors["hydrogen_industry_pattern"] = hydrogen_industry_pattern
    
    # 2.8 Fuel industry demand (relatively constant with small hourly variations)
    fuel_industry_pattern = 0.9 .+ 0.2 .* rand(hours_per_day)
    short_term_factors["fuel_industry_pattern"] = fuel_industry_pattern
    
    # 2.9 Grid carbon intensity (hourly, lower during high renewable periods)
    gamma_elec_patterns = Dict()
    for day_type in time_indices["typical_day_types"]
        solar_factor = solar_patterns[day_type]
        gamma_elec_patterns[day_type] = 0.5 .* (1.0 .- 0.3 .* solar_factor)
    end
    short_term_factors["gamma_elec_patterns"] = gamma_elec_patterns
    
    # 2.10 Transportation demand boundaries (daily limits)
    transport_boundaries = Dict(
        "D_ICV_min" => 0.0,
        "D_ICV_max" => 1000.0,
        "D_EV_min" => 0.0,
        "D_EV_max" => 1000.0,
        "D_HV_min" => 0.0,
        "D_HV_max" => 1000.0
    )
    short_term_factors["transport_boundaries"] = transport_boundaries
    
    # 2.11 Peak hours definition (for V2G and demand response)
    peak_hours = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0]
    short_term_factors["peak_hours"] = peak_hours
    
    scenarios["short_term_factors"] = short_term_factors
    
    # ===== 3. MEDIUM-TERM FACTORS (Annual/Seasonal) =====
    medium_term_factors = Dict()
    
    # 3.1 Cost parameters evolution (annual changes)
    cost_evolution = Dict()
    
    # Solar and wind costs decrease over time
    cost_evolution["c_solar"] = [0.08 * (1.0 - 0.03 * (y-1)) for y in 1:years]
    cost_evolution["c_wind"] = [0.07 * (1.0 - 0.025 * (y-1)) for y in 1:years]
    cost_evolution["c_fuel"] = [0.6 * (1.0 + 0.02 * (y-1)) for y in 1:years]  # Fuel costs increase
    cost_evolution["c_cert"] = [0.05 * (1.0 + 0.03 * (y-1)) for y in 1:years]  # Certificate costs increase
    
    medium_term_factors["cost_evolution"] = cost_evolution
    
    # 3.2 V2G incentive evolution (annual policy changes)
    V2G_incentive_evolution = [0.05 * (1.0 + 0.04 * (y-1)) for y in 1:years]
    medium_term_factors["V2G_incentive_evolution"] = V2G_incentive_evolution
    
    # 3.3 Vehicle energy dynamics parameters (evolving annually)
    vehicle_dynamics_evolution = Dict()
    
    # ICV parameters
    vehicle_dynamics_evolution["SOC_ICV_0"] = [30000.0 * (1.0 - 0.02 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["SOC_ICV_min"] = [5000.0 * (1.0 - 0.02 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["SOC_ICV_max"] = [50000.0 * (1.0 - 0.02 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["F_ICV_max"] = [5000.0 * (1.0 - 0.02 * (y-1)) for y in 1:years]
    
    # HV parameters
    vehicle_dynamics_evolution["SOC_HV_0"] = [5000.0 * (1.0 + 0.03 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["SOC_HV_min"] = [1000.0 * (1.0 + 0.03 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["SOC_HV_max"] = [10000.0 * (1.0 + 0.03 * (y-1)) for y in 1:years]
    vehicle_dynamics_evolution["H_HV_max"] = [1000.0 * (1.0 + 0.03 * (y-1)) for y in 1:years]
    
    medium_term_factors["vehicle_dynamics_evolution"] = vehicle_dynamics_evolution
    
    scenarios["medium_term_factors"] = medium_term_factors
    
    # ===== 4. LONG-TERM FACTORS (Multi-year Strategic) =====
    long_term_factors = Dict()
    
    # 4.1 Transportation parameters (long-term technology characteristics)
    transportation_params = Dict(
        "alpha_ICV" => 0.6,  # kWh/km for ICVs (improves slowly)
        "alpha_EV" => 0.2,   # kWh/km for EVs (improves faster)
        "alpha_HV" => 0.3    # kWh/km for HVs (improves moderately)
    )
    long_term_factors["transportation_params"] = transportation_params
    
    # 4.2 Storage parameters (long-term infrastructure characteristics)
    storage_params = Dict(
        "E_storage_0" => 100.0,
        "Q_storage_0" => 100.0,
        "H_storage_0" => 100.0,
        "E_storage_max" => 500.0,
        "Q_storage_max" => 500.0,
        "H_storage_max" => 500.0,
        "E_storage_min" => 50.0,
        "Q_storage_min" => 50.0,
        "H_storage_min" => 50.0,
        "P_storage_max" => 100.0,
        "Q_storage_max_rate" => 100.0,
        "H_storage_max_rate" => 100.0
    )
    long_term_factors["storage_params"] = storage_params
    
    # 4.3 Emissions parameters (long-term environmental targets)
    emissions_params = Dict(
        "CO2_budget" => 6000.0,
        "eta_CCUS" => 0.9,
        "eta_CCUS_PtF" => 0.6,
        "eta_C2F" => 0.2,
        "eta_CCUS_loss" => 0.2,
        "gamma_fuel" => 1.0
    )
    long_term_factors["emissions_params"] = emissions_params
    
    # 4.4 Conversion efficiencies (long-term technology performance)
    conversion_efficiencies = Dict(
        "eta_electrolysis" => 0.6,
        "eta_CHP" => 0.75,
        "eta_CHP_elec" => 0.35,
        "eta_CHP_th" => 0.4,
        "eta_heatpump" => 3.0,
        "eta_fuelcell" => 0.6,
        "eta_power_to_fuel" => 0.3,
        "eta_wasteheat" => 0.3,
        "eta_EV_charge" => 0.95,
        "eta_EV_discharge" => 0.9
    )
    long_term_factors["conversion_efficiencies"] = conversion_efficiencies
    
    # 4.5 Storage decay rates (long-term technology characteristics)
    storage_decay_rates = Dict(
        "eta_elec" => 0.98,
        "eta_th" => 0.9,
        "eta_hydrogen" => 0.99,
        "eta_CH" => 0.95,
        "eta_DC" => 0.95
    )
    long_term_factors["storage_decay_rates"] = storage_decay_rates
    
    # 4.6 Component maximum capacities (long-term infrastructure limits)
    component_capacities = Dict(
        "P_heatpump_max" => 500.0,
        "P_electrolysis_max" => 300.0,
        "P_CHP_max" => 400.0,
        "P_fuelcell_max" => 100.0,
        "P_solar_rated" => 500.0,
        "P_wind_rated" => 500.0
    )
    long_term_factors["component_capacities"] = component_capacities
    
    # 4.7 Vehicle fleet ratios (long-term policy and market evolution)
    vehicle_fleet_evolution = Dict()
    for y in 1:years
        # Gradual electrification over time
        EV_growth = min(0.8, 0.3 + 0.025 * (y-1))
        HV_growth = min(0.2, 0.1 + 0.005 * (y-1))
        ICV_decline = max(0.0, 0.6 - 0.03 * (y-1))
        
        # Normalize to ensure sum equals 1
        total = EV_growth + HV_growth + ICV_decline
        vehicle_fleet_evolution[y] = Dict(
            "EV_ratio" => EV_growth / total,
            "HV_ratio" => HV_growth / total,
            "ICV_ratio" => ICV_decline / total
        )
    end
    long_term_factors["vehicle_fleet_evolution"] = vehicle_fleet_evolution
    
    # 4.8 Carbon price evolution (long-term policy trajectory)
    carbon_price_evolution = [50.0 * (1.0 + 0.05 * (y-1)) for y in 1:years]
    long_term_factors["carbon_price_evolution"] = carbon_price_evolution
    
    # 4.9 Carbon intensity targets (long-term environmental goals)
    carbon_intensity_targets = [0.3 * (1.0 - 0.03 * (y-1)) for y in 1:years]
    long_term_factors["carbon_intensity_targets"] = carbon_intensity_targets
    
    # 4.10 Carbon reduction targets (long-term emission reduction goals)
    carbon_reduction_targets = [0.4 + 0.02 * (y-1) for y in 1:years]
    long_term_factors["carbon_reduction_targets"] = carbon_reduction_targets
    
    # 4.11 V2G parameters (long-term vehicle grid integration)
    V2G_params = Dict(
        "SOC_EV_0" => 300.0,
        "SOC_EV_min" => 100.0,
        "SOC_EV_max" => 500.0,
        "P_EV_max" => 100.0
    )
    long_term_factors["V2G_params"] = V2G_params
    
    scenarios["long_term_factors"] = long_term_factors
    
    # ===== 5. Generate Integrated Scenario Configuration =====
    selected_config = Dict(
        "name" => "multi_timescale_scenario",
        "description" => "Multi-timescale lifecycle scenario with proper parameter categorization",
        "short_term_variability" => 0.1,    # 10% hourly variability
        "medium_term_variability" => 0.05,  # 5% annual variability
        "long_term_variability" => 0.02     # 2% multi-year variability
    )
    
    scenarios["selected_config"] = selected_config
    
    return scenarios
end

"""
    save_scenarios_to_csv(scenarios, output_dir="scenarios")

Save generated scenario data to CSV files for subsequent analysis and use

Parameters:
- scenarios: Scenario data generated by generate_lifecycle_scenarios
- output_dir: Output directory, default "scenarios"
"""
function save_scenarios_to_csv(scenarios, output_dir="scenarios")
    # Create output directory
    if !isdir(output_dir)
        mkdir(output_dir)
    end
    
    # Save time structure
    time_df = DataFrame(
        years = scenarios["time_structure"]["years"],
        typical_days = scenarios["time_structure"]["typical_days"],
        hours_per_day = scenarios["time_structure"]["hours_per_day"],
        total_periods = scenarios["time_structure"]["total_periods"]
    )
    CSV.write(joinpath(output_dir, "time_structure.csv"), time_df)
    
    # Save typical day types
    typical_days_df = DataFrame(day_type = scenarios["time_indices"]["typical_day_types"])
    CSV.write(joinpath(output_dir, "typical_day_types.csv"), typical_days_df)
    
    # Save typical day weights
    weights_df = DataFrame(
        day_type = collect(keys(scenarios["typical_day_weights"])),
        weight = collect(values(scenarios["typical_day_weights"]))
    )
    CSV.write(joinpath(output_dir, "typical_day_weights.csv"), weights_df)
    
    # Save annual carbon budget and carbon price
    annual_df = DataFrame(
        year = 1:scenarios["time_structure"]["years"],
        carbon_budget = scenarios["annual_data"]["carbon_budget"],
        carbon_price = scenarios["annual_data"]["carbon_price"]
    )
    CSV.write(joinpath(output_dir, "annual_data.csv"), annual_df)
    
    # Save technology efficiency and cost evolution
    for tech in keys(scenarios["annual_data"]["efficiency_factors"])
        tech_df = DataFrame(
            year = 1:scenarios["time_structure"]["years"],
            efficiency = scenarios["annual_data"]["efficiency_factors"][tech],
            cost = scenarios["annual_data"]["cost_factors"][tech]
        )
        CSV.write(joinpath(output_dir, "tech_evolution_$(tech).csv"), tech_df)
    end
    
    # Save load growth factors
    load_growth_df = DataFrame(
        year = 1:scenarios["time_structure"]["years"],
        electricity = scenarios["annual_data"]["electricity_load_factors"],
        thermal = scenarios["annual_data"]["thermal_load_factors"],
        hydrogen = scenarios["annual_data"]["hydrogen_load_factors"],
        transport = scenarios["annual_data"]["transport_load_factors"]
    )
    CSV.write(joinpath(output_dir, "load_growth_factors.csv"), load_growth_df)
    
    # Save typical day data
    for (day_type, day_data) in scenarios["typical_days_data"]
        day_df = DataFrame(hour = 1:24)
        
        for (data_type, values) in day_data
            day_df[!, data_type] = values
        end
        
        # 替换文件名中的空格和特殊字符
        safe_name = replace(day_type, " " => "_")
        safe_name = replace(safe_name, "季" => "")
        
        CSV.write(joinpath(output_dir, "typical_day_$(safe_name).csv"), day_df)
    end
    
    # 保存全生命周期参数
    # 投资成本
    investment_df = DataFrame(
        technology = collect(keys(scenarios["lifecycle_params"]["initial_investment"])),
        initial_investment = collect(values(scenarios["lifecycle_params"]["initial_investment"])),
        lifetime = [scenarios["lifecycle_params"]["lifetime"][tech] for tech in keys(scenarios["lifecycle_params"]["initial_investment"])],
        annual_om = [scenarios["lifecycle_params"]["annual_O&M"][tech] for tech in keys(scenarios["lifecycle_params"]["initial_investment"])],
        replacement_cost = [scenarios["lifecycle_params"]["replacement_cost"][tech] for tech in keys(scenarios["lifecycle_params"]["initial_investment"])],
        salvage_value = [scenarios["lifecycle_params"]["salvage_value"][tech] for tech in keys(scenarios["lifecycle_params"]["initial_investment"])]
    )
    CSV.write(joinpath(output_dir, "lifecycle_economic_params.csv"), investment_df)
    
    # 碳排放参数
    emissions_df = DataFrame(
        technology = collect(keys(scenarios["lifecycle_params"]["construction_emissions"])),
        construction = collect(values(scenarios["lifecycle_params"]["construction_emissions"])),
        decommission = [scenarios["lifecycle_params"]["decommission_emissions"][tech] for tech in keys(scenarios["lifecycle_params"]["construction_emissions"])]
    )
    # 添加运行期排放因子（如果存在）
    if haskey(scenarios["lifecycle_params"], "operation_emissions_factor")
        emissions_df.operation = [get(scenarios["lifecycle_params"]["operation_emissions_factor"], tech, 0.0) 
                                 for tech in emissions_df.technology]
    end
    CSV.write(joinpath(output_dir, "lifecycle_emissions_params.csv"), emissions_df)
    
    # 保存场景配置
    scenario_config_df = DataFrame(
        parameter = ["name", "description", "carbon_budget_path", "carbon_price_path", 
                    "tech_evolution_rate", "demand_growth_rate", "renewable_target"],
        value = [
            scenarios["selected_config"]["name"],
            scenarios["selected_config"]["description"],
            scenarios["selected_config"]["carbon_budget_path"],
            scenarios["selected_config"]["carbon_price_path"],
            scenarios["selected_config"]["tech_evolution_rate"],
            scenarios["selected_config"]["demand_growth_rate"],
            scenarios["selected_config"]["renewable_target"]
        ]
    )
    CSV.write(joinpath(output_dir, "scenario_config.csv"), scenario_config_df)
    
    println("所有场景数据已保存到 $(output_dir) 目录")
end

