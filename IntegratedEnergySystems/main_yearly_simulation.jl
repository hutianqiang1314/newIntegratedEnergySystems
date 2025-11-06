# main_yearly_simulation.jl
# Main program entry point for coordinating the entire simulation analysis process

using JuMP
using Ipopt
using Plots
using DataFrames
using CSV
using PlotlyJS
using Dates

# Include necessary files
include("model.jl")
include("solver.jl")
include("parameters.jl")
include("analysis.jl")
include("visualization.jl")
include("yearly_profile.jl")
include("yearly_simulation.jl")

"""
    run_yearly_simulation(typical_days_data_path::String, output_dir::String, scenario_params::Dict{String, Any})

Run typical day-based annual simulation analysis
"""
function run_yearly_simulation(typical_days_data_path::String, output_dir::String, scenario_params::Dict{String, Any})
    println("Starting typical day-based annual simulation analysis...")
    
    # 1. Load typical day data
    println("1. Loading typical day data...")
    if !isfile(typical_days_data_path)
        println("   Generating typical day data file...")
        generate_typical_day_data(typical_days_data_path)
    end
    typical_days_data = load_typical_day_data(typical_days_data_path)
    
    # 2. Get typical day weights
    println("2. Getting typical day weights...")
    weights = get_typical_day_weights()
    
    # 3. Create calendar mapping
    println("3. Creating calendar mapping...")
    calendar = create_yearly_calendar(2025)
    day_mapping = map_calendar_to_typical_days(calendar)
    day_mapping = adjust_mapping_for_weights(day_mapping, weights)
    hour_mapping = create_hourly_mapping(day_mapping)
    
    # 4. Simulate each typical day
    println("4. Simulating each typical day...")
    typical_days_results = Dict()
    typical_day_ids = get_typical_day_ids()
    
    for typical_day_id in typical_day_ids
        println("   Simulating typical day: $typical_day_id")
        
        try
            # Prepare parameters - merge base parameters and scenario parameters
            params = prepare_typical_day_parameters(typical_day_id, typical_days_data)
            
            # Apply scenario parameter overrides
            for (key, value) in scenario_params
                if key != "scenario_description"
                    params[key] = value
                end
            end
            
            # Create model
            model = create_low_carbon_energy_system_model(params)
            
            # Solve model
            results = solve_model(model)
            
            # Check solve status - handle case where results might not have "status" key
            solve_status = get(results, "success", "Unknown")
            if solve_status != true
                @warn "Typical day $typical_day_id solve status: $solve_status"
            end
            
            # Analyze results
            analysis_results = analyze_typical_day_results(results, params)
            results["analysis"] = analysis_results
            
            # Store results
            typical_days_results[typical_day_id] = results
            
        catch e
            @error "Error simulating typical day $typical_day_id: $e"
            # Create empty results to maintain consistency
            typical_days_results[typical_day_id] = Dict(
                "status" => "Error",
                "error" => string(e),
                "analysis" => Dict("status" => "Error")
            )
        end
    end
    
    # 5. Connect storage states
    println("5. Connecting storage states...")
    connected_results = connect_storage_states(typical_days_results, day_mapping)
    
    # 6. Reconstruct annual results
    println("6. Reconstructing annual results...")
    yearly_results = reconstruct_yearly_results(connected_results, hour_mapping)
    yearly_results = apply_seasonal_adjustments!(yearly_results, hour_mapping)
    
    # 7. Calculate annual metrics
    println("7. Calculating annual metrics...")
    yearly_metrics = calculate_yearly_metrics(yearly_results, connected_results, weights)
    monthly_metrics = calculate_monthly_metrics(yearly_results, connected_results, hour_mapping, weights)
    
    # 8. Save intermediate results
    println("8. Saving results...")
    save_simulation_results(yearly_results, yearly_metrics, monthly_metrics, typical_days_results, output_dir)
    
    println("Annual simulation analysis completed!")
    
    return yearly_results, yearly_metrics, monthly_metrics, typical_days_results
end

# Analyze typical day results
function analyze_typical_day_results(results, params)
    # Check results status - handle missing status key
    solve_status = get(results, "success", "Unknown")
    if solve_status != true
        @warn "Result status is not optimal: $solve_status"
        return Dict("status" => solve_status, "total_cost" => 0.0, "total_emissions" => 0.0, 
                   "renewable_percentage" => 0.0, "ev_share" => 0.0)
    end
    
    # Get time range
    T = params["T"]
    
    # Safe function to get array values with better error handling
    function safe_sum(arr)
        if arr === nothing || isempty(arr)
            return 0.0
        end
        try
            return sum(arr)
        catch e
            @warn "Error summing array: $e"
            return 0.0
        end
    end
    
    # Safe function to get scalar values
    function safe_get(dict, key, default=0.0)
        try
            val = get(dict, key, default)
            return val === nothing ? default : (isa(val, Number) ? val : default)
        catch e
            @warn "Error getting key $key: $e"
            return default
        end
    end
    
    # Calculate total energy from different sources with error handling
    total_grid = safe_sum(get(results, "P_grid", Float64[]))
    total_solar = safe_sum(get(results, "P_solar", Float64[]))
    total_wind = safe_sum(get(results, "P_wind", Float64[]))
    total_CHP = safe_sum(get(results, "P_CHP", Float64[]))
    total_fuelcell = safe_sum(get(results, "P_fuelcell", Float64[]))
    
    # Calculate total emissions with error handling
    gamma_elec = safe_get(params, "gamma_elec", 0.5)
    if isa(gamma_elec, Vector)
        P_grid_vals = get(results, "P_grid", zeros(length(gamma_elec)))
        if length(P_grid_vals) == length(gamma_elec)
            grid_emissions = sum(gamma_elec .* P_grid_vals)
        else
            grid_emissions = (isa(gamma_elec, Vector) ? gamma_elec[1] : gamma_elec) * total_grid
        end
    else
        grid_emissions = gamma_elec * total_grid
    end
    
    # Fuel emissions
    gamma_fuel = safe_get(params, "gamma_fuel", 1.0)
    total_fuel = safe_sum(get(results, "F_fuel", Float64[]))
    fuel_emissions = gamma_fuel * total_fuel
    
    # Carbon capture
    total_captured = safe_sum(get(results, "CO2_captured", Float64[]))
    
    # Net emissions
    net_emissions = grid_emissions + fuel_emissions - total_captured
    
    # Calculate renewable energy percentage
    total_electricity = total_grid + total_solar + total_wind + total_CHP + total_fuelcell
    renewable_percentage = total_electricity > 0 ? (total_solar + total_wind) / total_electricity * 100 : 0.0
    
    # Calculate total cost with error handling
    c_grid = safe_get(params, "c_grid", 0.15)
    if isa(c_grid, Vector) && haskey(results, "P_grid")
        P_grid_vals = results["P_grid"]
        if length(P_grid_vals) == length(c_grid)
            grid_cost = sum(c_grid .* P_grid_vals)
        else
            grid_cost = (length(c_grid) > 0 ? c_grid[1] : 0.15) * total_grid
        end
    else
        grid_cost = (isa(c_grid, Vector) && length(c_grid) > 0 ? c_grid[1] : c_grid) * total_grid
    end
    
    c_fuel = safe_get(params, "c_fuel", 0.6)
    c_cert = safe_get(params, "c_cert", 0.05)
    lambda_penalty = safe_get(params, "lambda", 0.1)
    CO2_budget = safe_get(params, "CO2_budget", 6000.0)
    c_solar = safe_get(params, "c_solar", 0.08)
    c_wind = safe_get(params, "c_wind", 0.07)
    
    fuel_cost = c_fuel * total_fuel
    cert_cost = c_cert * safe_sum(get(results, "Cert_purchase", Float64[]))
    carbon_penalty = lambda_penalty * max(0, net_emissions - CO2_budget)
    solar_cost = c_solar * total_solar
    wind_cost = c_wind * total_wind
    
    total_cost = grid_cost + fuel_cost + cert_cost + carbon_penalty + solar_cost + wind_cost
    
    # Transportation energy statistics with error handling
    total_ICV = safe_sum(get(results, "D_ICV", Float64[]))
    total_EV = safe_sum(get(results, "D_EV", Float64[]))
    total_HV = safe_sum(get(results, "D_HV", Float64[]))
    total_transport = total_ICV + total_EV + total_HV
    
    # Return key indicators with safe calculations
    return Dict(
        "total_grid" => total_grid,
        "total_solar" => total_solar,
        "total_wind" => total_wind,
        "total_CHP" => total_CHP,
        "total_fuelcell" => total_fuelcell,
        "grid_emissions" => grid_emissions,
        "fuel_emissions" => fuel_emissions,
        "total_emissions" => net_emissions,
        "renewable_percentage" => renewable_percentage,
        "total_cost" => total_cost,
        "grid_cost" => grid_cost,
        "fuel_cost" => fuel_cost,
        "cert_cost" => cert_cost,
        "carbon_penalty" => carbon_penalty,
        "total_ICV" => total_ICV,
        "total_EV" => total_EV,
        "total_HV" => total_HV,
        "ev_share" => total_transport > 0 ? total_EV / total_transport : 0.0,
        "hv_share" => total_transport > 0 ? total_HV / total_transport : 0.0,
        "icv_share" => total_transport > 0 ? total_ICV / total_transport : 0.0,
        "status" => "Analyzed"
    )
end

"""
    save_simulation_results(yearly_results, yearly_metrics, monthly_metrics, typical_days_results, output_dir)

Save simulation results to files
"""
function save_simulation_results(yearly_results, yearly_metrics, monthly_metrics, typical_days_results, output_dir)
    # Ensure output directory exists
    mkpath(output_dir)
    
    try
        # Save annual metrics
        if !isempty(yearly_metrics)
            yearly_df = DataFrame(
                Metric = collect(keys(yearly_metrics)),
                Value = collect(values(yearly_metrics))
            )
            CSV.write(joinpath(output_dir, "yearly_metrics.csv"), yearly_df)
        end
        
        # Save monthly metrics
        if !isempty(monthly_metrics)
            CSV.write(joinpath(output_dir, "monthly_metrics.csv"), monthly_metrics)
        end
        
        # Save typical day analysis results
        typical_days_analysis = DataFrame(
            TypicalDay = String[],
            TotalCost = Float64[],
            TotalEmissions = Float64[],
            RenewableShare = Float64[],
            EVShare = Float64[],
            Status = String[]
        )
        
        for (day_id, results) in typical_days_results
            analysis = get(results, "analysis", Dict())
            push!(typical_days_analysis, [
                day_id,
                get(analysis, "total_cost", 0.0),
                get(analysis, "total_emissions", 0.0),
                get(analysis, "renewable_percentage", 0.0),
                get(analysis, "ev_share", 0.0),
                get(analysis, "status", "Unknown")
            ])
        end
        
        CSV.write(joinpath(output_dir, "typical_days_analysis.csv"), typical_days_analysis)
        
        println("   Results saved to: $output_dir")
        
    catch e
        @warn "Error saving results: $e"
    end
end

"""
    run_scenario_analysis(typical_days_data_path::String, output_dir::String)

Run annual simulation analysis for different scenarios
"""
function run_scenario_analysis(typical_days_data_path::String, output_dir::String)
    println("\n===== Starting Scenario Analysis =====")
    
    # Get scenario parameters
    scenarios = create_carbon_budget_scenarios()
    
    # Store results for each scenario
    scenario_results = Dict()
    
    # Run simulation for each scenario
    for (scenario_name, scenario_params) in scenarios
        println("\nRunning scenario: $(get(scenario_params, "scenario_description", scenario_name))")
        
        # Create scenario output directory
        scenario_dir = joinpath(output_dir, scenario_name)
        mkpath(scenario_dir)
        
        try
            # Run annual simulation
            yearly_results, yearly_metrics, monthly_metrics, typical_days_results = run_yearly_simulation(
                typical_days_data_path, scenario_dir, scenario_params
            )
            
            # Store results
            scenario_results[scenario_name] = Dict(
                "yearly_results" => yearly_results,
                "yearly_metrics" => yearly_metrics,
                "monthly_metrics" => monthly_metrics,
                "typical_days_results" => typical_days_results,
                "scenario_params" => scenario_params
            )
            
            println("Scenario $scenario_name completed")
            
        catch e
            @error "Scenario $scenario_name failed: $e"
            scenario_results[scenario_name] = Dict(
                "status" => "Error",
                "error" => string(e),
                "scenario_params" => scenario_params
            )
        end
    end
    
    # Compare different scenarios
    println("\n===== Scenario Comparison =====")
    comparison_results = compare_scenarios(scenario_results, output_dir)
    
    println("Scenario analysis completed!")
    return scenario_results, comparison_results
end

"""
    compare_scenarios(scenario_results::Dict, output_dir::String)

Compare results from different scenarios
"""
function compare_scenarios(scenario_results::Dict, output_dir::String)
    println("Generating scenario comparison report...")
    
    # Compare key indicators
    comparison = DataFrame(
        Scenario = String[],
        Description = String[],
        TotalCost = Float64[],
        TotalEmissions = Float64[],
        RenewableShare = Float64[],
        EVShare = Float64[],
        Status = String[]
    )
    
    for (scenario_name, results) in scenario_results
        if haskey(results, "yearly_metrics") && !isempty(results["yearly_metrics"])
            metrics = results["yearly_metrics"]
            scenario_params = get(results, "scenario_params", Dict())
            
            push!(comparison, [
                scenario_name,
                get(scenario_params, "scenario_description", ""),
                get(metrics, "total_cost", 0.0),
                get(metrics, "total_emissions", 0.0),
                get(metrics, "renewable_share", 0.0),
                get(metrics, "ev_share", 0.0),
                "Completed"
            ])
        else
            push!(comparison, [
                scenario_name,
                get(get(results, "scenario_params", Dict()), "scenario_description", ""),
                0.0, 0.0, 0.0, 0.0,
                get(results, "status", "Unknown")
            ])
        end
    end
    
    # Print comparison results
    println(comparison)
    
    # Save comparison results
    try
        CSV.write(joinpath(output_dir, "scenario_comparison.csv"), comparison)
        println("Scenario comparison results saved to: $(joinpath(output_dir, "scenario_comparison.csv"))")
    catch e
        @warn "Error saving scenario comparison results: $e"
    end
    
    return comparison
end

"""
    main(case_name::String="baseline")

Main function - following carbon_analysis main.jl structure
"""
function main(case_name::String="baseline")
    println("Starting annual energy system simulation analysis: $case_name")
    
    # Parameter settings
    typical_days_data_path = "typical_days.csv"
    output_dir = joinpath("results", case_name)
    
    # Ensure output directory exists
    mkpath(output_dir)
    
    try
        if case_name == "scenario_analysis"
            # Run complete scenario analysis
            scenario_results, comparison_results = run_scenario_analysis(typical_days_data_path, output_dir)
            
            # Generate summary report
            print_scenario_summary(comparison_results)
            
            return scenario_results
        else
            # Run single scenario
            scenarios = create_carbon_budget_scenarios()
            scenario_params = get(scenarios, case_name, Dict("scenario_description" => "Custom case"))
            
            yearly_results, yearly_metrics, monthly_metrics, typical_days_results = run_yearly_simulation(
                typical_days_data_path, output_dir, scenario_params
            )
            
            # Print results summary
            print_single_case_summary(yearly_metrics, scenario_params)
            
            return Dict(
                "yearly_results" => yearly_results,
                "yearly_metrics" => yearly_metrics,
                "monthly_metrics" => monthly_metrics,
                "typical_days_results" => typical_days_results
            )
        end
        
    catch e
        @error "Main function execution failed: $e"
        return Dict("status" => "Error", "error" => string(e))
    end
end

"""
    print_scenario_summary(comparison_results::DataFrame)

Print scenario analysis summary
"""
function print_scenario_summary(comparison_results::DataFrame)
    println("\n" * "="^60)
    println("Scenario Analysis Summary")
    println("="^60)
    
    for row in eachrow(comparison_results)
        println("Scenario: $(row.Scenario)")
        println("  Description: $(row.Description)")
        println("  Total Cost: $(round(row.TotalCost, digits=2))")
        println("  Total Emissions: $(round(row.TotalEmissions, digits=2)) kg CO₂")
        println("  Renewable Share: $(round(row.RenewableShare, digits=1))%")
        println("  EV Share: $(round(row.EVShare * 100, digits=1))%")
        println("  Status: $(row.Status)")
        println()
    end
end

"""
    print_single_case_summary(yearly_metrics::Dict, scenario_params::Dict)

Print single case summary
"""
function print_single_case_summary(yearly_metrics::Dict, scenario_params::Dict)
    println("\n" * "="^60)
    println("Simulation Results Summary")
    println("="^60)
    println("Scenario: $(get(scenario_params, "scenario_description", "Unknown"))")
    println("Total Cost: $(round(get(yearly_metrics, "total_cost", 0.0), digits=2))")
    println("Total Emissions: $(round(get(yearly_metrics, "total_emissions", 0.0), digits=2)) kg CO₂")
    println("Renewable Share: $(round(get(yearly_metrics, "renewable_share", 0.0), digits=1))%")
    println("EV Share: $(round(get(yearly_metrics, "ev_share", 0.0) * 100, digits=1))%")
    println("="^60)
end


"""
    connect_storage_states(typical_days_results::Dict, day_mapping::Vector{Any})

Connect storage states between typical days (placeholder implementation)
"""
function connect_storage_states(typical_days_results::Dict, day_mapping::Vector{Any})
    # Simple placeholder - just return the typical days results
    # In a full implementation, this would handle storage state continuity
    return typical_days_results
end

"""
    reconstruct_yearly_results(connected_results::Dict, hour_mapping::Vector{Any})

Reconstruct full year results from typical day results (placeholder implementation)
"""
function reconstruct_yearly_results(connected_results::Dict, hour_mapping::Vector{Any})
    # Simple placeholder - aggregate typical day results
    yearly_results = Dict()
    
    # Initialize arrays for key variables
    yearly_results["P_grid"] = Float64[]
    yearly_results["P_solar"] = Float64[]
    yearly_results["P_wind"] = Float64[]
    yearly_results["total_cost"] = 0.0
    yearly_results["total_emissions"] = 0.0
    
    return yearly_results
end

"""
    apply_seasonal_adjustments!(yearly_results::Dict, hour_mapping::Vector{Any})

Apply seasonal adjustments to yearly results (placeholder implementation)
"""
function apply_seasonal_adjustments!(yearly_results::Dict, hour_mapping::Vector{Any})
    # Placeholder - no adjustments applied
    return yearly_results
end

"""
    calculate_yearly_metrics(yearly_results::Dict, connected_results::Dict, weights::Dict{String, Float64})

Calculate yearly metrics from simulation results
"""
function calculate_yearly_metrics(yearly_results::Dict, connected_results::Dict, weights::Dict{String, Float64})
    metrics = Dict()
    
    # Initialize with safe defaults
    total_cost = 0.0
    total_emissions = 0.0
    total_renewable = 0.0
    total_electricity = 0.0
    total_ev = 0.0
    total_transport = 0.0
    
    # Aggregate metrics from typical day results
    for (day_id, day_results) in connected_results
        if haskey(day_results, "analysis")
            analysis = day_results["analysis"]
            weight = get(weights, day_id, 1.0)
            
            # Safely aggregate metrics
            total_cost += get(analysis, "total_cost", 0.0) * weight
            total_emissions += get(analysis, "total_emissions", 0.0) * weight
            
            # Renewable energy
            solar = get(analysis, "total_solar", 0.0) * weight
            wind = get(analysis, "total_wind", 0.0) * weight
            total_renewable += solar + wind
            
            # Total electricity
            grid = get(analysis, "total_grid", 0.0) * weight
            chp = get(analysis, "total_CHP", 0.0) * weight
            fuelcell = get(analysis, "total_fuelcell", 0.0) * weight
            total_electricity += grid + solar + wind + chp + fuelcell
            
            # Transportation
            ev = get(analysis, "total_EV", 0.0) * weight
            icv = get(analysis, "total_ICV", 0.0) * weight
            hv = get(analysis, "total_HV", 0.0) * weight
            total_ev += ev
            total_transport += ev + icv + hv
        end
    end
    
    # Calculate derived metrics
    renewable_share = total_electricity > 0 ? total_renewable / total_electricity * 100 : 0.0
    ev_share = total_transport > 0 ? total_ev / total_transport : 0.0
    system_efficiency = 0.75  # Placeholder value
    
    metrics["total_cost"] = total_cost
    metrics["total_emissions"] = total_emissions
    metrics["renewable_share"] = renewable_share
    metrics["ev_share"] = ev_share
    metrics["system_efficiency"] = system_efficiency
    metrics["total_electricity"] = total_electricity
    metrics["total_renewable"] = total_renewable
    
    return metrics
end

"""
    calculate_monthly_metrics(yearly_results::Dict, connected_results::Dict, hour_mapping::Vector{Any}, weights::Dict{String, Float64})

Calculate monthly metrics (placeholder implementation)
"""
function calculate_monthly_metrics(yearly_results::Dict, connected_results::Dict, hour_mapping::Vector{Any}, weights::Dict{String, Float64})
    # Create a simple monthly breakdown
    monthly_df = DataFrame(
        Month = 1:12,
        TotalCost = zeros(12),
        TotalEmissions = zeros(12),
        RenewableShare = zeros(12)
    )
    
    # Distribute annual metrics across months (simplified)
    yearly_metrics = calculate_yearly_metrics(yearly_results, connected_results, weights)
    
    for month in 1:12
        monthly_df[month, :TotalCost] = get(yearly_metrics, "total_cost", 0.0) / 12
        monthly_df[month, :TotalEmissions] = get(yearly_metrics, "total_emissions", 0.0) / 12
        monthly_df[month, :RenewableShare] = get(yearly_metrics, "renewable_share", 0.0)
    end
    
    return monthly_df
end


# If running this file directly, execute main function
# if abspath(PROGRAM_FILE) == @__FILE__
    # Can specify case name through command line arguments
    case_name = length(ARGS) > 0 ? ARGS[1] : "scenario_analysis"
    main(case_name)
# end