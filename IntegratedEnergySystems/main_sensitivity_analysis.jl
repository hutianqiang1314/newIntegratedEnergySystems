# Main script for sensitivity analysis of carbon budget, renewable capacities, and grid carbon emission intensity

using JuMP
using Ipopt
using Plots
using DataFrames
using CSV
using Statistics

# Include the necessary files
include("model.jl")
include("solver.jl")
include("parameters.jl")
include("analysis.jl")
include("visualization.jl")

"""
    create_sensitivity_scenarios()

Create sensitivity analysis scenarios for carbon budget, renewable capacities, and grid carbon intensity
"""
function create_sensitivity_scenarios()
    # Get base parameters
    base_params = create_sample_parameters()
    scenarios = Dict()
    
    # ===== Carbon Budget Sensitivity =====
    base_budget = base_params["CO2_budget"]
    carbon_budget_variations = [0.5, 0.7, 0.8, 1.0, 1.2, 1.5, 2.0]  # Multipliers for base budget
    
    for (i, multiplier) in enumerate(carbon_budget_variations)
        scenario_name = "carbon_budget_$(Int(multiplier*100))pct"
        scenario_params = deepcopy(base_params)
        scenario_params["CO2_budget"] = base_budget * multiplier
        scenario_params["scenario_description"] = "Carbon Budget $(Int(multiplier*100))% of baseline"
        scenario_params["sensitivity_type"] = "carbon_budget"
        scenario_params["sensitivity_value"] = multiplier
        scenarios[scenario_name] = scenario_params
    end
    
    # ===== Renewable Energy Capacity Sensitivity =====
    base_solar = base_params["P_solar_rated"]
    base_wind = base_params["P_wind_rated"]
    renewable_variations = [0.3, 0.5, 0.8, 1.0, 1.5, 2.0, 3.0]  # Multipliers for renewable capacity
    
    for (i, multiplier) in enumerate(renewable_variations)
        scenario_name = "renewable_$(Int(multiplier*100))pct"
        scenario_params = deepcopy(base_params)
        scenario_params["P_solar_rated"] = base_solar * multiplier
        scenario_params["P_wind_rated"] = base_wind * multiplier
        # Update P_solar_max and P_wind_max proportionally
        scenario_params["P_solar_max"] = scenario_params["P_solar_max"] .* multiplier
        scenario_params["P_wind_max"] = scenario_params["P_wind_max"] .* multiplier
        scenario_params["scenario_description"] = "Renewable Capacity $(Int(multiplier*100))% of baseline"
        scenario_params["sensitivity_type"] = "renewable_capacity"
        scenario_params["sensitivity_value"] = multiplier
        scenarios[scenario_name] = scenario_params
    end
    
    # ===== Grid Carbon Intensity Sensitivity =====
    base_gamma_elec = mean(base_params["gamma_elec"])  # Average grid carbon intensity
    carbon_intensity_variations = [0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5]  # Multipliers for carbon intensity
    
    for (i, multiplier) in enumerate(carbon_intensity_variations)
        scenario_name = "grid_carbon_$(Int(multiplier*100))pct"
        scenario_params = deepcopy(base_params)
        scenario_params["gamma_elec"] = scenario_params["gamma_elec"] .* multiplier
        scenario_params["scenario_description"] = "Grid Carbon Intensity $(Int(multiplier*100))% of baseline"
        scenario_params["sensitivity_type"] = "grid_carbon"
        scenario_params["sensitivity_value"] = multiplier
        scenarios[scenario_name] = scenario_params
    end
    
    return scenarios
end

"""
    run_sensitivity_analysis()

Run comprehensive sensitivity analysis
"""
function run_sensitivity_analysis()
    println("Running comprehensive sensitivity analysis...")
    
    # Create sensitivity scenarios
    scenarios = create_sensitivity_scenarios()
    
    # Dictionary to store results from all scenarios
    scenario_results = Dict()
    scenario_metrics = Dict()
    
    for (scenario_name, params) in scenarios
        println("\n" * "="^60)
        println("Running scenario: $(params["scenario_description"])")
        println("Sensitivity Type: $(params["sensitivity_type"])")
        println("Sensitivity Value: $(params["sensitivity_value"])")
        println("="^60)
        
        try
            # Extract time steps
            T = params["T"]
            
            # Create and solve the model using the same methodology as main_carbon_budget.jl
            model = create_low_carbon_energy_system_model(params)
            solve_result = solve_model(model)
            
            # Extract results using the same methodology as main_carbon_budget.jl
            results = extract_results(model)
            
            if results !== nothing
                # Analyze results using the same functions as main_carbon_budget.jl
                general_metrics = analyze_results(results, T, params)
                efficiency_metrics = analyze_system_efficiency(results, T, params)
                
                # Extract carbon-specific metrics using consistent methodology
                carbon_metrics = extract_carbon_metrics(results, T, params)
                
                # Check energy balance using the same function as main_carbon_budget.jl
                balance_ok = check_energy_balance(results, T, params)
                
                # Store results
                scenario_results[scenario_name] = results
                scenario_metrics[scenario_name] = Dict(
                    "general" => general_metrics,
                    "efficiency" => efficiency_metrics,
                    "carbon" => carbon_metrics,
                    "energy_balance_ok" => balance_ok,
                    "scenario_description" => params["scenario_description"],
                    "sensitivity_type" => params["sensitivity_type"],
                    "sensitivity_value" => params["sensitivity_value"],
                    "CO2_budget" => params["CO2_budget"]
                )
                
                # Print summary using the same format as main_carbon_budget.jl
                if carbon_metrics["success"]
                    println("\nScenario Results Summary:")
                    println("Net Emissions: $(round(carbon_metrics["net_emissions"], digits=2)) kg CO2")
                    println("Carbon Budget Utilization: $(round(carbon_metrics["carbon_budget_utilization"], digits=2))%")
                    println("Carbon Intensity: $(round(carbon_metrics["carbon_intensity"], digits=4)) kg CO2/kWh")
                    println("Renewable Percentage: $(round(carbon_metrics["renewable_percentage"], digits=2))%")
                    println("System Efficiency: $(round(efficiency_metrics["system_efficiency"], digits=2))%")
                    println("Energy Balance OK: $balance_ok")
                else
                    println("Failed to analyze carbon metrics for scenario: $scenario_name")
                end
                
            else
                println("Failed to solve scenario: $scenario_name")
                scenario_metrics[scenario_name] = Dict(
                    "error" => "Failed to solve model",
                    "scenario_description" => params["scenario_description"],
                    "sensitivity_type" => params["sensitivity_type"],
                    "sensitivity_value" => params["sensitivity_value"],
                    "CO2_budget" => params["CO2_budget"]
                )
            end
            
        catch e
            println("Error in scenario $scenario_name: $e")
            scenario_metrics[scenario_name] = Dict(
                "error" => string(e),
                "scenario_description" => params["scenario_description"],
                "sensitivity_type" => params["sensitivity_type"],
                "sensitivity_value" => params["sensitivity_value"],
                "CO2_budget" => params["CO2_budget"]
            )
        end
    end
    
    # Create sensitivity analysis using the same calculation methods as main_carbon_budget.jl
    sensitivity_results = create_sensitivity_analysis(scenario_metrics)
    
    # Generate sensitivity visualizations
    if !isempty(scenario_results)
        generate_sensitivity_visualizations(scenario_metrics)
    end
    
    println("\n" * "="^60)
    println("Sensitivity analysis completed!")
    println("="^60)
    
    return scenario_results, scenario_metrics, sensitivity_results
end

"""
    extract_carbon_metrics(results, T, params)

Extract carbon metrics using the same methodology as main_carbon_budget.jl
"""
function extract_carbon_metrics(results, T, params)
    # Use the same validation and calculation methodology as main_carbon_budget.jl
    validation = validate_analysis_inputs(results, T, params)
    if !validation["success"]
        return validation
    end
    params = validation["params"]
    
    # Extract gamma values using the same method as main_carbon_budget.jl
    gamma_elec, gamma_fuel = extract_gamma_values(results, params, T)
    
    # Calculate emissions using the same methodology as main_carbon_budget.jl
    emissions = calculate_emissions(results, params, gamma_elec, gamma_fuel, T)
    
    # Calculate basic energy totals using the same method as main_carbon_budget.jl
    energy_totals = calculate_energy_totals(results, T)
    
    # Calculate renewable percentage using the same methodology as main_carbon_budget.jl
    total_electricity_generation = energy_totals["total_grid"] + energy_totals["total_solar"] + 
                                  energy_totals["total_wind"] + energy_totals["total_CHP_elec"] + 
                                  energy_totals["total_fuelcell"]
    renewable_percentage = total_electricity_generation > 0 ? 
                          (energy_totals["total_solar"] + energy_totals["total_wind"]) / total_electricity_generation * 100 : 0.0
    
    # Calculate carbon intensity using the same methodology as main_carbon_budget.jl
    total_electricity_demand = safe_sum(results, "P_industry_elec", T) + safe_sum(results, "P_buildings_elec", T) + 
                              safe_sum(results, "P_EV_charge", T) - safe_sum(results, "P_EV_V2G", T)
    total_heat_demand = safe_sum(results, "Q_industry_th", T) + safe_sum(results, "Q_buildings_th", T)
    total_hydrogen_demand = energy_totals["total_hydrogen_industry"] + energy_totals["total_hydrogen_fuelcell"] + 
                           energy_totals["total_hydrogen_vehicles"]
    
    total_energy_output = total_electricity_demand + total_heat_demand / params["eta_heatpump"] + 
                         total_hydrogen_demand / params["eta_electrolysis"]
    
    carbon_intensity = total_energy_output > 0 ? emissions["net_emissions"] / total_energy_output : 0.0
    
    # Calculate carbon budget utilization
    CO2_budget = get(params, "CO2_budget", 0.0)
    carbon_budget_utilization = CO2_budget > 0 ? emissions["net_emissions"] / CO2_budget * 100 : 0.0
    
    # Calculate specific carbon metrics (same as main_carbon_budget.jl)
    carbon_metrics = Dict(
        # Emissions breakdown (same as main_carbon_budget.jl)
        "grid_emissions" => emissions["grid_emissions"],
        "fuel_emissions" => emissions["fuel_emissions"],
        "total_emissions_before_capture" => emissions["total_emissions_before_capture"],
        "total_captured" => emissions["total_captured"],
        "total_certificates" => emissions["total_certificates"],
        "net_emissions" => emissions["net_emissions"],
        
        # Carbon performance indicators
        "carbon_intensity" => carbon_intensity,
        "carbon_budget_utilization" => carbon_budget_utilization,
        "renewable_percentage" => renewable_percentage,
        
        # Energy service carbon intensities
        "electricity_carbon_intensity" => total_electricity_demand > 0 ? emissions["grid_emissions"] / total_electricity_demand : 0.0,
        "heat_carbon_intensity" => total_heat_demand > 0 ? 0.0 : 0.0,  # Assuming heat is from electric sources
        "transport_carbon_intensity" => (energy_totals["total_ICV_distance"] + energy_totals["total_EV_distance"] + energy_totals["total_HV_distance"]) > 0 ? 
                                       (energy_totals["total_fuel_ICV"] * gamma_fuel) / (energy_totals["total_ICV_distance"] + energy_totals["total_EV_distance"] + energy_totals["total_HV_distance"]) : 0.0,
        
        # Carbon reduction potential
        "carbon_capture_efficiency" => emissions["total_emissions_before_capture"] > 0 ? 
                                      emissions["total_captured"] / emissions["total_emissions_before_capture"] * 100 : 0.0,
        
        # System carbon efficiency
        "carbon_efficiency_score" => 100.0 - carbon_budget_utilization,  # Higher is better
        
        "success" => true
    )
    
    return carbon_metrics
end

"""
    create_sensitivity_analysis(scenario_metrics)

Create sensitivity analysis using consistent methodology with main_carbon_budget.jl
"""
function create_sensitivity_analysis(scenario_metrics)
    println("\n===== Sensitivity Analysis Results =====")
    
    # Group scenarios by sensitivity type
    carbon_budget_scenarios = []
    renewable_capacity_scenarios = []
    grid_carbon_scenarios = []
    
    for (scenario_name, metrics) in scenario_metrics
        if haskey(metrics, "sensitivity_type") && haskey(metrics, "carbon") && metrics["carbon"]["success"]
            if metrics["sensitivity_type"] == "carbon_budget"
                push!(carbon_budget_scenarios, (metrics["sensitivity_value"], metrics))
            elseif metrics["sensitivity_type"] == "renewable_capacity"
                push!(renewable_capacity_scenarios, (metrics["sensitivity_value"], metrics))
            elseif metrics["sensitivity_type"] == "grid_carbon"
                push!(grid_carbon_scenarios, (metrics["sensitivity_value"], metrics))
            end
        end
    end
    
    # Sort scenarios by sensitivity value
    sort!(carbon_budget_scenarios, by = x -> x[1])
    sort!(renewable_capacity_scenarios, by = x -> x[1])
    sort!(grid_carbon_scenarios, by = x -> x[1])
    
    # Analyze each sensitivity type
    results = Dict()
    
    if !isempty(carbon_budget_scenarios)
        results["carbon_budget"] = analyze_carbon_budget_sensitivity(carbon_budget_scenarios)
    end
    
    if !isempty(renewable_capacity_scenarios)
        results["renewable_capacity"] = analyze_renewable_capacity_sensitivity(renewable_capacity_scenarios)
    end
    
    if !isempty(grid_carbon_scenarios)
        results["grid_carbon"] = analyze_grid_carbon_sensitivity(grid_carbon_scenarios)
    end
    
    return results
end

"""
    analyze_carbon_budget_sensitivity(scenarios)

Analyze carbon budget sensitivity
"""
function analyze_carbon_budget_sensitivity(scenarios)
    println("\n----- Carbon Budget Sensitivity Analysis -----")
    
    # Extract data
    budget_multipliers = [s[1] for s in scenarios]
    net_emissions = [s[2]["carbon"]["net_emissions"] for s in scenarios]
    system_efficiency = [s[2]["efficiency"]["system_efficiency"] for s in scenarios]
    renewable_percentage = [s[2]["carbon"]["renewable_percentage"] for s in scenarios]
    carbon_intensity = [s[2]["carbon"]["carbon_intensity"] for s in scenarios]
    
    # Calculate sensitivity metrics
    emissions_elasticity = calculate_elasticity(budget_multipliers, net_emissions)
    efficiency_elasticity = calculate_elasticity(budget_multipliers, system_efficiency)
    renewable_elasticity = calculate_elasticity(budget_multipliers, renewable_percentage)
    
    println("Carbon Budget Sensitivity Results:")
    println("Net Emissions Elasticity: $(round(emissions_elasticity, digits=4))")
    println("System Efficiency Elasticity: $(round(efficiency_elasticity, digits=4))")
    println("Renewable Percentage Elasticity: $(round(renewable_elasticity, digits=4))")
    
    return Dict(
        "budget_multipliers" => budget_multipliers,
        "net_emissions" => net_emissions,
        "system_efficiency" => system_efficiency,
        "renewable_percentage" => renewable_percentage,
        "carbon_intensity" => carbon_intensity,
        "emissions_elasticity" => emissions_elasticity,
        "efficiency_elasticity" => efficiency_elasticity,
        "renewable_elasticity" => renewable_elasticity
    )
end

"""
    analyze_renewable_capacity_sensitivity(scenarios)

Analyze renewable capacity sensitivity
"""
function analyze_renewable_capacity_sensitivity(scenarios)
    println("\n----- Renewable Capacity Sensitivity Analysis -----")
    
    # Extract data
    capacity_multipliers = [s[1] for s in scenarios]
    net_emissions = [s[2]["carbon"]["net_emissions"] for s in scenarios]
    system_efficiency = [s[2]["efficiency"]["system_efficiency"] for s in scenarios]
    renewable_percentage = [s[2]["carbon"]["renewable_percentage"] for s in scenarios]
    carbon_intensity = [s[2]["carbon"]["carbon_intensity"] for s in scenarios]
    
    # Calculate sensitivity metrics
    emissions_elasticity = calculate_elasticity(capacity_multipliers, net_emissions)
    efficiency_elasticity = calculate_elasticity(capacity_multipliers, system_efficiency)
    renewable_elasticity = calculate_elasticity(capacity_multipliers, renewable_percentage)
    
    println("Renewable Capacity Sensitivity Results:")
    println("Net Emissions Elasticity: $(round(emissions_elasticity, digits=4))")
    println("System Efficiency Elasticity: $(round(efficiency_elasticity, digits=4))")
    println("Renewable Percentage Elasticity: $(round(renewable_elasticity, digits=4))")
    
    return Dict(
        "capacity_multipliers" => capacity_multipliers,
        "net_emissions" => net_emissions,
        "system_efficiency" => system_efficiency,
        "renewable_percentage" => renewable_percentage,
        "carbon_intensity" => carbon_intensity,
        "emissions_elasticity" => emissions_elasticity,
        "efficiency_elasticity" => efficiency_elasticity,
        "renewable_elasticity" => renewable_elasticity
    )
end

"""
    analyze_grid_carbon_sensitivity(scenarios)

Analyze grid carbon intensity sensitivity
"""
function analyze_grid_carbon_sensitivity(scenarios)
    println("\n----- Grid Carbon Intensity Sensitivity Analysis -----")
    
    # Extract data
    carbon_multipliers = [s[1] for s in scenarios]
    net_emissions = [s[2]["carbon"]["net_emissions"] for s in scenarios]
    system_efficiency = [s[2]["efficiency"]["system_efficiency"] for s in scenarios]
    renewable_percentage = [s[2]["carbon"]["renewable_percentage"] for s in scenarios]
    carbon_intensity = [s[2]["carbon"]["carbon_intensity"] for s in scenarios]
    
    # Calculate sensitivity metrics
    emissions_elasticity = calculate_elasticity(carbon_multipliers, net_emissions)
    efficiency_elasticity = calculate_elasticity(carbon_multipliers, system_efficiency)
    renewable_elasticity = calculate_elasticity(carbon_multipliers, renewable_percentage)
    
    println("Grid Carbon Intensity Sensitivity Results:")
    println("Net Emissions Elasticity: $(round(emissions_elasticity, digits=4))")
    println("System Efficiency Elasticity: $(round(efficiency_elasticity, digits=4))")
    println("Renewable Percentage Elasticity: $(round(renewable_elasticity, digits=4))")
    
    return Dict(
        "carbon_multipliers" => carbon_multipliers,
        "net_emissions" => net_emissions,
        "system_efficiency" => system_efficiency,
        "renewable_percentage" => renewable_percentage,
        "carbon_intensity" => carbon_intensity,
        "emissions_elasticity" => emissions_elasticity,
        "efficiency_elasticity" => efficiency_elasticity,
        "renewable_elasticity" => renewable_elasticity
    )
end

"""
    calculate_elasticity(x, y)

Calculate elasticity between two variables
"""
function calculate_elasticity(x, y)
    if length(x) < 2 || length(y) < 2
        return 0.0
    end
    
    # Calculate percentage changes
    x_changes = []
    y_changes = []
    
    for i in 2:length(x)
        if x[i-1] != 0 && y[i-1] != 0
            x_change = (x[i] - x[i-1]) / x[i-1]
            y_change = (y[i] - y[i-1]) / y[i-1]
            push!(x_changes, x_change)
            push!(y_changes, y_change)
        end
    end
    
    if isempty(x_changes) || isempty(y_changes)
        return 0.0
    end
    
    # Calculate average elasticity
    elasticities = []
    for i in 1:length(x_changes)
        if x_changes[i] != 0
            push!(elasticities, y_changes[i] / x_changes[i])
        end
    end
    
    return isempty(elasticities) ? 0.0 : mean(elasticities)
end

"""
    generate_sensitivity_visualizations(scenario_metrics)

Generate sensitivity analysis visualizations using the same methodology as main_carbon_budget.jl
"""
function generate_sensitivity_visualizations(scenario_metrics)
    println("\nGenerating sensitivity analysis visualizations...")
    
    # Create sensitivity plots using the same visualization methodology as main_carbon_budget.jl
    create_sensitivity_plots(scenario_metrics)
    
    println("Sensitivity analysis visualizations generated successfully.")
end

"""
    create_sensitivity_plots(scenario_metrics)

Create sensitivity analysis plots
"""
function create_sensitivity_plots(scenario_metrics)
    # Group scenarios by sensitivity type (same logic as create_sensitivity_analysis)
    carbon_budget_data = []
    renewable_capacity_data = []
    grid_carbon_data = []
    
    for (scenario_name, metrics) in scenario_metrics
        if haskey(metrics, "sensitivity_type") && haskey(metrics, "carbon") && metrics["carbon"]["success"]
            data_point = (
                metrics["sensitivity_value"],
                metrics["carbon"]["net_emissions"],
                metrics["efficiency"]["system_efficiency"],
                metrics["carbon"]["renewable_percentage"],
                metrics["carbon"]["carbon_intensity"]
            )
            
            if metrics["sensitivity_type"] == "carbon_budget"
                push!(carbon_budget_data, data_point)
            elseif metrics["sensitivity_type"] == "renewable_capacity"
                push!(renewable_capacity_data, data_point)
            elseif metrics["sensitivity_type"] == "grid_carbon"
                push!(grid_carbon_data, data_point)
            end
        end
    end
    
    # Sort data by sensitivity value
    sort!(carbon_budget_data, by = x -> x[1])
    sort!(renewable_capacity_data, by = x -> x[1])
    sort!(grid_carbon_data, by = x -> x[1])
    
    # Create plots for each sensitivity type
    if !isempty(carbon_budget_data)
        create_carbon_budget_plots(carbon_budget_data)
    end
    
    if !isempty(renewable_capacity_data)
        create_renewable_capacity_plots(renewable_capacity_data)
    end
    
    if !isempty(grid_carbon_data)
        create_grid_carbon_plots(grid_carbon_data)
    end
    
    # Create comprehensive comparison plot
    create_comprehensive_sensitivity_plot(carbon_budget_data, renewable_capacity_data, grid_carbon_data)
end

"""
    create_carbon_budget_plots(data)

Create carbon budget sensitivity plots
"""
function create_carbon_budget_plots(data)
    multipliers = [d[1] for d in data]
    net_emissions = [d[2] for d in data]
    system_efficiency = [d[3] for d in data]
    renewable_percentage = [d[4] for d in data]
    
    # Plot 1: Carbon Budget vs Net Emissions
    p1 = Plots.plot(
        multipliers, net_emissions,
        title="Carbon Budget Sensitivity: Net Emissions",
        xlabel="Carbon Budget Multiplier",
        ylabel="Net Emissions (kg CO2)",
        marker=:circle,
        linewidth=2,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 2: Carbon Budget vs System Efficiency
    p2 = Plots.plot(
        multipliers, system_efficiency,
        title="Carbon Budget Sensitivity: System Efficiency",
        xlabel="Carbon Budget Multiplier",
        ylabel="System Efficiency (%)",
        marker=:square,
        linewidth=2,
        color=:red,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 3: Carbon Budget vs Renewable Percentage
    p3 = Plots.plot(
        multipliers, renewable_percentage,
        title="Carbon Budget Sensitivity: Renewable Percentage",
        xlabel="Carbon Budget Multiplier",
        ylabel="Renewable Percentage (%)",
        marker=:diamond,
        linewidth=2,
        color=:green,
        legend=false,
        size=(800, 500)
    )
    
    # Save plots
    try
        if !isdir("results")
            mkdir("results")
        end
        Plots.savefig(p1, "results/carbon_budget_emissions_sensitivity.png")
        Plots.savefig(p2, "results/carbon_budget_efficiency_sensitivity.png")
        Plots.savefig(p3, "results/carbon_budget_renewable_sensitivity.png")
        
        # Combined plot
        combined = Plots.plot(p1, p2, p3, layout=(1,3), size=(1800, 500))
        Plots.savefig(combined, "results/carbon_budget_sensitivity_combined.png")
        
        println("Carbon budget sensitivity plots saved successfully")
    catch e
        println("Error saving carbon budget sensitivity plots: $e")
    end
    
    # Save data to CSV
    try
        df = DataFrame(
            "Carbon_Budget_Multiplier" => multipliers,
            "Net_Emissions_kg_CO2" => net_emissions,
            "System_Efficiency_pct" => system_efficiency,
            "Renewable_Percentage_pct" => renewable_percentage
        )
        CSV.write("results/carbon_budget_sensitivity_data.csv", df)
        println("Carbon budget sensitivity data saved to CSV")
    catch e
        println("Error saving carbon budget sensitivity data: $e")
    end
end

"""
    create_renewable_capacity_plots(data)

Create renewable capacity sensitivity plots
"""
function create_renewable_capacity_plots(data)
    multipliers = [d[1] for d in data]
    net_emissions = [d[2] for d in data]
    system_efficiency = [d[3] for d in data]
    renewable_percentage = [d[4] for d in data]
    
    # Plot 1: Renewable Capacity vs Net Emissions
    p1 = Plots.plot(
        multipliers, net_emissions,
        title="Renewable Capacity Sensitivity: Net Emissions",
        xlabel="Renewable Capacity Multiplier",
        ylabel="Net Emissions (kg CO2)",
        marker=:circle,
        linewidth=2,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 2: Renewable Capacity vs System Efficiency
    p2 = Plots.plot(
        multipliers, system_efficiency,
        title="Renewable Capacity Sensitivity: System Efficiency",
        xlabel="Renewable Capacity Multiplier",
        ylabel="System Efficiency (%)",
        marker=:square,
        linewidth=2,
        color=:red,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 3: Renewable Capacity vs Renewable Percentage
    p3 = Plots.plot(
        multipliers, renewable_percentage,
        title="Renewable Capacity Sensitivity: Renewable Percentage",
        xlabel="Renewable Capacity Multiplier",
        ylabel="Renewable Percentage (%)",
        marker=:diamond,
        linewidth=2,
        color=:green,
        legend=false,
        size=(800, 500)
    )
    
    # Save plots
    try
        if !isdir("results")
            mkdir("results")
        end
        Plots.savefig(p1, "results/renewable_capacity_emissions_sensitivity.png")
        Plots.savefig(p2, "results/renewable_capacity_efficiency_sensitivity.png")
        Plots.savefig(p3, "results/renewable_capacity_renewable_sensitivity.png")
        
        # Combined plot
        combined = Plots.plot(p1, p2, p3, layout=(1,3), size=(1800, 500))
        Plots.savefig(combined, "results/renewable_capacity_sensitivity_combined.png")
        
        println("Renewable capacity sensitivity plots saved successfully")
    catch e
        println("Error saving renewable capacity sensitivity plots: $e")
    end
    
    # Save data to CSV
    try
        df = DataFrame(
            "Renewable_Capacity_Multiplier" => multipliers,
            "Net_Emissions_kg_CO2" => net_emissions,
            "System_Efficiency_pct" => system_efficiency,
            "Renewable_Percentage_pct" => renewable_percentage
        )
        CSV.write("results/renewable_capacity_sensitivity_data.csv", df)
        println("Renewable capacity sensitivity data saved to CSV")
    catch e
        println("Error saving renewable capacity sensitivity data: $e")
    end
end

"""
    create_grid_carbon_plots(data)

Create grid carbon intensity sensitivity plots
"""
function create_grid_carbon_plots(data)
    multipliers = [d[1] for d in data]
    net_emissions = [d[2] for d in data]
    system_efficiency = [d[3] for d in data]
    renewable_percentage = [d[4] for d in data]
    
    # Plot 1: Grid Carbon Intensity vs Net Emissions
    p1 = Plots.plot(
        multipliers, net_emissions,
        title="Grid Carbon Intensity Sensitivity: Net Emissions",
        xlabel="Grid Carbon Intensity Multiplier",
        ylabel="Net Emissions (kg CO2)",
        marker=:circle,
        linewidth=2,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 2: Grid Carbon Intensity vs System Efficiency
    p2 = Plots.plot(
        multipliers, system_efficiency,
        title="Grid Carbon Intensity Sensitivity: System Efficiency",
        xlabel="Grid Carbon Intensity Multiplier",
        ylabel="System Efficiency (%)",
        marker=:square,
        linewidth=2,
        color=:red,
        legend=false,
        size=(800, 500)
    )
    
    # Plot 3: Grid Carbon Intensity vs Renewable Percentage
    p3 = Plots.plot(
        multipliers, renewable_percentage,
        title="Grid Carbon Intensity Sensitivity: Renewable Percentage",
        xlabel="Grid Carbon Intensity Multiplier",
        ylabel="Renewable Percentage (%)",
        marker=:diamond,
        linewidth=2,
        color=:green,
        legend=false,
        size=(800, 500)
    )
    
    # Save plots
    try
        if !isdir("results")
            mkdir("results")
        end
        Plots.savefig(p1, "results/grid_carbon_emissions_sensitivity.png")
        Plots.savefig(p2, "results/grid_carbon_efficiency_sensitivity.png")
        Plots.savefig(p3, "results/grid_carbon_renewable_sensitivity.png")
        
        # Combined plot
        combined = Plots.plot(p1, p2, p3, layout=(1,3), size=(1800, 500))
        Plots.savefig(combined, "results/grid_carbon_sensitivity_combined.png")
        
        println("Grid carbon intensity sensitivity plots saved successfully")
    catch e
        println("Error saving grid carbon intensity sensitivity plots: $e")
    end
    
    # Save data to CSV
    try
        df = DataFrame(
            "Grid_Carbon_Intensity_Multiplier" => multipliers,
            "Net_Emissions_kg_CO2" => net_emissions,
            "System_Efficiency_pct" => system_efficiency,
            "Renewable_Percentage_pct" => renewable_percentage
        )
        CSV.write("results/grid_carbon_sensitivity_data.csv", df)
        println("Grid carbon intensity sensitivity data saved to CSV")
    catch e
        println("Error saving grid carbon intensity sensitivity data: $e")
    end
end

"""
    create_comprehensive_sensitivity_plot(carbon_data, renewable_data, grid_data)

Create comprehensive sensitivity comparison plot
"""
function create_comprehensive_sensitivity_plot(carbon_data, renewable_data, grid_data)
    try
        # Normalize data for comparison (convert to percentage change from baseline)
        normalize_data = function(data, baseline_idx=4)  # Assuming baseline is at index 4 (multiplier = 1.0)
            if length(data) >= baseline_idx
                baseline_emissions = data[baseline_idx][2]
                return [(d[1], (d[2] - baseline_emissions) / baseline_emissions * 100) for d in data]
            else
                return [(d[1], 0.0) for d in data]
            end
        end
        
        # Create comprehensive comparison plot
        p = Plots.plot(
            title="Comprehensive Sensitivity Analysis: Net Emissions",
            xlabel="Parameter Multiplier",
            ylabel="Net Emissions Change (%)",
            size=(1000, 600),
            legend=:topleft
        )
        
        if !isempty(carbon_data)
            norm_carbon = normalize_data(carbon_data)
            Plots.plot!(p, [d[1] for d in norm_carbon], [d[2] for d in norm_carbon],
                       label="Carbon Budget", marker=:circle, linewidth=2)
        end
        
        if !isempty(renewable_data)
            norm_renewable = normalize_data(renewable_data)
            Plots.plot!(p, [d[1] for d in norm_renewable], [d[2] for d in norm_renewable],
                       label="Renewable Capacity", marker=:square, linewidth=2, color=:red)
        end
        
        if !isempty(grid_data)
            norm_grid = normalize_data(grid_data)
            Plots.plot!(p, [d[1] for d in norm_grid], [d[2] for d in norm_grid],
                       label="Grid Carbon Intensity", marker=:diamond, linewidth=2, color=:green)
        end
        
        # Add horizontal line at zero
        Plots.hline!(p, [0], linestyle=:dash, color=:black, alpha=0.5, label="Baseline")
        
        # Save plot
        if !isdir("results")
            mkdir("results")
        end
        Plots.savefig(p, "results/comprehensive_sensitivity_comparison.png")
        println("Comprehensive sensitivity comparison plot saved successfully")
        
    catch e
        println("Error creating comprehensive sensitivity plot: $e")
    end
end

# Main function
function main()
    println("========== Comprehensive Sensitivity Analysis: Carbon Budget, Renewable Capacity, and Grid Carbon Intensity ==========")
    
    # Create results directory
    if !isdir("results")
        mkdir("results")
    end
    
    # Run the sensitivity analysis
    scenario_results, scenario_metrics, sensitivity_results = run_sensitivity_analysis()
    
    println("\nSensitivity analysis completed, results saved to results/ directory")
    
    return scenario_results, scenario_metrics, sensitivity_results
end

# Run main program
scenario_results, scenario_metrics, sensitivity_results = main()
