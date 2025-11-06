# Main script for carbon budget scenario analysis

using JuMP
using Ipopt
using Plots
using DataFrames
using CSV
using PlotlyJS

# Include the necessary files
include("model.jl")
include("solver.jl")
include("parameters.jl")
include("analysis.jl")
include("visualization.jl")

# Function to extract carbon metrics using the same methodology as analysis.jl
function extract_carbon_metrics(results, T, params)
    # Use the same validation and calculation methodology as analysis.jl
    validation = validate_analysis_inputs(results, T, params)
    if !validation["success"]
        return validation
    end
    params = validation["params"]
    
    # Extract gamma values using the same method as analysis.jl
    gamma_elec, gamma_fuel = extract_gamma_values(results, params, T)
    
    # Calculate emissions using the same methodology as analysis.jl
    emissions = calculate_emissions(results, params, gamma_elec, gamma_fuel, T)
    
    # Calculate basic energy totals using the same method as analysis.jl
    energy_totals = calculate_energy_totals(results, T)
    
    # Calculate renewable percentage using the same methodology
    total_electricity_generation = energy_totals["total_grid"] + energy_totals["total_solar"] + 
                                  energy_totals["total_wind"] + energy_totals["total_CHP_elec"] + 
                                  energy_totals["total_fuelcell"]
    renewable_percentage = total_electricity_generation > 0 ? 
                          (energy_totals["total_solar"] + energy_totals["total_wind"]) / total_electricity_generation * 100 : 0.0
    
    # Calculate carbon intensity using the same methodology as analyze_system_efficiency
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
    
    # Calculate specific carbon metrics
    carbon_metrics = Dict(
        # Emissions breakdown (same as analysis.jl)
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

# Function to run carbon budget scenario analysis
function run_carbon_budget_analysis()
    println("Running carbon budget scenario analysis...")
    
    # Create carbon budget scenarios using the same parameters structure
    scenarios = create_carbon_budget_scenarios()
    
    # Dictionary to store results from all scenarios
    scenario_results = Dict()
    scenario_metrics = Dict()
    
    for (scenario_name, params) in scenarios
        println("\n" * "="^50)
        println("Running scenario: $(params["scenario_description"])")
        println("CO2 Budget: $(params["CO2_budget"]) kg")
        println("="^50)
        
        try
            # Extract time steps
            T = params["T"]
            
            # Create and solve the model
            model = create_low_carbon_energy_system_model(params)
            solve_result = solve_model(model)
            
            # Extract results using the same methodology as main.jl
            results = extract_results(model)
            
            if results !== nothing
                # Analyze results using the same functions as main.jl
                general_metrics = analyze_results(results, T, params)
                efficiency_metrics = analyze_system_efficiency(results, T, params)
                
                # Extract carbon-specific metrics using consistent methodology
                carbon_metrics = extract_carbon_metrics(results, T, params)
                
                # Check energy balance using the same function as main.jl
                balance_ok = check_energy_balance(results, T, params)
                
                # Store results
                scenario_results[scenario_name] = results
                scenario_metrics[scenario_name] = Dict(
                    "general" => general_metrics,
                    "efficiency" => efficiency_metrics,
                    "carbon" => carbon_metrics,
                    "energy_balance_ok" => balance_ok,
                    "scenario_description" => params["scenario_description"],
                    "CO2_budget" => params["CO2_budget"]
                )
                
                # Print summary using the same format as main.jl would
                if carbon_metrics["success"]
                    println("\nScenario Results Summary:")
                    println("Net Emissions: $(round(carbon_metrics["net_emissions"], digits=2)) kg CO2")
                    println("Carbon Budget Utilization: $(round(carbon_metrics["carbon_budget_utilization"], digits=2))%")
                    println("Carbon Intensity: $(round(carbon_metrics["carbon_intensity"], digits=4)) kg CO2/kWh")
                    println("Renewable Percentage: $(round(carbon_metrics["renewable_percentage"], digits=2))%")
                    println("Energy Balance OK: $balance_ok")
                else
                    println("Failed to analyze carbon metrics for scenario: $scenario_name")
                end
                
            else
                println("Failed to solve scenario: $scenario_name")
                scenario_metrics[scenario_name] = Dict(
                    "error" => "Failed to solve model",
                    "scenario_description" => params["scenario_description"],
                    "CO2_budget" => params["CO2_budget"]
                )
            end
            
        catch e
            println("Error in scenario $scenario_name: $e")
            scenario_metrics[scenario_name] = Dict(
                "error" => string(e),
                "scenario_description" => params["scenario_description"],
                "CO2_budget" => params["CO2_budget"]
            )
        end
    end
    
    # Create comparative analysis using the same calculation methods
    comparative_results = create_comparative_analysis(scenario_metrics)
    
    # Generate visualizations using the same methodology as main.jl
    if !isempty(scenario_results)
        generate_scenario_visualizations(scenario_results, scenario_metrics)
    end
    
    println("\n" * "="^50)
    println("Carbon budget scenario analysis completed!")
    println("="^50)
    
    return scenario_results, scenario_metrics, comparative_results
end

# Function to create comparative analysis using consistent methodology
function create_comparative_analysis(scenario_metrics)
    println("\n===== Comparative Analysis =====")
    
    # Extract metrics for comparison using the same structure as analysis.jl
    comparison_data = []
    
    for (scenario_name, metrics) in scenario_metrics
        if haskey(metrics, "carbon") && metrics["carbon"]["success"]
            carbon = metrics["carbon"]
            general = get(metrics, "general", Dict())
            
            push!(comparison_data, Dict(
                "scenario" => scenario_name,
                "description" => get(metrics, "scenario_description", "Unknown"),
                "CO2_budget" => get(metrics, "CO2_budget", 0.0),
                "net_emissions" => carbon["net_emissions"],
                "carbon_budget_utilization" => carbon["carbon_budget_utilization"],
                "carbon_intensity" => carbon["carbon_intensity"],
                "renewable_percentage" => carbon["renewable_percentage"],
                "total_grid" => get(general, "total_grid", 0.0),
                "total_solar" => get(general, "total_solar", 0.0),
                "total_wind" => get(general, "total_wind", 0.0)
            ))
        end
    end
    
    # Sort by carbon budget utilization (same metric used in carbon analysis)
    sort!(comparison_data, by = x -> x["carbon_budget_utilization"])
    
    # Print comparison table using simple string formatting
    println("\nScenario Comparison (sorted by carbon budget utilization):")
    println("-" * "="^80)
    println(rpad("Scenario", 25) * rpad("Budget (kg)", 15) * rpad("Emissions (kg)", 15) * rpad("Utilization (%)", 15) * "Renewable (%)")
    println("-" * "="^80)
    
    for data in comparison_data
        scenario_name = rpad(data["description"][1:min(end,24)], 25)
        budget_str = rpad(string(round(data["CO2_budget"], digits=0)), 15)
        emissions_str = rpad(string(round(data["net_emissions"], digits=2)), 15)
        utilization_str = rpad(string(round(data["carbon_budget_utilization"], digits=2)), 15)
        renewable_str = string(round(data["renewable_percentage"], digits=2))
        
        println(scenario_name * budget_str * emissions_str * utilization_str * renewable_str)
    end
    
    return comparison_data
end

# Function to generate scenario visualizations using the same methods as visualization.jl
function generate_scenario_visualizations(scenario_results, scenario_metrics)
    println("\nGenerating scenario visualizations...")
    
    # Use the first successful scenario to get T and params structure
    first_scenario = first(keys(scenario_results))
    sample_results = scenario_results[first_scenario]
    sample_metrics = scenario_metrics[first_scenario]
    
    # Create comparison plots using the same visualization methodology
    create_carbon_comparison_plots(scenario_metrics)
    
    # Generate individual scenario plots using the same method as main.jl
    for (scenario_name, results) in scenario_results
        if haskey(scenario_metrics, scenario_name) && haskey(scenario_metrics[scenario_name], "carbon")
            println("Generating plots for scenario: $scenario_name")
            
            # Get the original scenario parameters to extract the correct renewable potentials
            scenarios = create_carbon_budget_scenarios()
            scenario_params = scenarios[scenario_name]
            
            # Create a basic params dict for visualization (same structure as main.jl)
            T = length(results["P_grid"])
            basic_params = Dict(
                "T" => T,
                "eta_heatpump" => 3.0,  # Default values consistent with analysis.jl
                "eta_electrolysis" => 0.7,
                "eta_power_to_fuel" => 0.3,
                "eta_wasteheat" => 0.3,  # Add missing parameter
                "P_solar_max" => scenario_params["P_solar_max"],  # Use actual solar potential from scenario parameters
                "P_wind_max" => scenario_params["P_wind_max"],    # Use actual wind potential from scenario parameters
                # Add missing transportation parameters
                "alpha_ICV" => 0.6,  # kWh/km for ICVs
                "alpha_EV" => 0.2,   # kWh/km for EVs
                "alpha_HV" => 0.3,   # kWh/km for HVs
                "eta_EV_charge" => 0.95,  # EV charging efficiency
                "eta_EV_discharge" => 0.9,  # EV discharging efficiency
                # Add missing storage efficiency parameters
                "eta_elec" => 0.98,  # Electricity storage decay rate
                "eta_th" => 0.9,     # Thermal storage decay rate
                "eta_hydrogen" => 0.99,  # Hydrogen storage decay rate
                "eta_CH" => 0.95,    # Charging efficiency
                "eta_DC" => 0.95,    # Discharging efficiency
                # Add missing conversion efficiency parameters
                "eta_CHP" => 0.75,   # Total efficiency of CHP
                "eta_CHP_elec" => 0.35,  # Electrical efficiency of CHP
                "eta_CHP_th" => 0.4,     # Thermal efficiency of CHP
                "eta_fuelcell" => 0.6,  # Efficiency of fuel cells
                # Add missing parameter checking variables
                "gamma_elec" => fill(0.5, T),  # Grid carbon intensity
                "gamma_fuel" => 1.0   # Fuel carbon intensity
            )
            
            # Use the same visualization functions as main.jl
            try
                visualize_all_results(results, T, basic_params)
                # Rename files to include scenario name
                if isfile("energy_system_results.png")
                    mv("energy_system_results.png", "$(scenario_name)_energy_system_results.png", force=true)
                end
                if isfile("energy_sankey.html")
                    mv("energy_sankey.html", "$(scenario_name)_energy_sankey.html", force=true)
                end
            catch e
                println("Warning: Could not generate full visualization for $scenario_name: $e")
            end
        end
    end
end

# Function to create carbon-specific comparison plots
function create_carbon_comparison_plots(scenario_metrics)
    # Extract data for plotting using the same data structure as analysis.jl
    scenarios = []
    emissions = []
    budgets = []
    utilizations = []
    renewable_pcts = []
    
    for (scenario_name, metrics) in scenario_metrics
        if haskey(metrics, "carbon") && metrics["carbon"]["success"]
            push!(scenarios, get(metrics, "scenario_description", scenario_name))
            push!(emissions, metrics["carbon"]["net_emissions"])
            push!(budgets, get(metrics, "CO2_budget", 0.0))
            push!(utilizations, metrics["carbon"]["carbon_budget_utilization"])
            push!(renewable_pcts, metrics["carbon"]["renewable_percentage"])
        end
    end
    
    if !isempty(scenarios)
        # Create comparison plots using the same plotting methodology as visualization.jl
        p1 = Plots.bar(scenarios, emissions, 
                      title="Net Emissions by Scenario",
                      ylabel="Net Emissions (kg CO2)",
                      xrotation=45,
                      legend=false)
        
        p2 = Plots.bar(scenarios, utilizations,
                      title="Carbon Budget Utilization",
                      ylabel="Utilization (%)",
                      xrotation=45,
                      legend=false)
        
        p3 = Plots.bar(scenarios, renewable_pcts,
                      title="Renewable Energy Percentage",
                      ylabel="Renewable (%)",
                      xrotation=45,
                      legend=false)
        
        combined_plot = Plots.plot(p1, p2, p3, layout=(1,3), size=(1200, 400))
        Plots.savefig(combined_plot, "carbon_budget_comparison.png")
        
        println("Carbon budget comparison plots saved.")
    end
end

# Run the carbon budget analysis if this script is executed directly
# if abspath(PROGRAM_FILE) == @__FILE__
    scenario_results, scenario_metrics, comparative_results = run_carbon_budget_analysis()
# end
