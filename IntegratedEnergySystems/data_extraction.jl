# Data Extraction Module - handles extracting and processing scenario data

using DataFrames
using Statistics

"""
    extract_scenario_data(paths)

Extract key scenario data from scenario paths for analysis.
"""
function extract_scenario_data(paths)
    println("\n=== Scenario Data Extraction ===")
    
    scenario_data = DataFrame(
        path_id = Int[],
        probability = Float64[],
        year = Int[],
        typical_day = String[],
        hour = Int[],
        demand_growth = Float64[],
        carbon_budget = Float64[],
        carbon_price = Float64[],
        electricity_load = Float64[],
        thermal_load = Float64[],
        solar_output = Float64[],
        wind_output = Float64[]
    )
    
    # Check if paths is valid and not empty
    if isempty(paths)
        println("Warning: No scenario paths provided")
        return scenario_data
    end
    
    for (i, path) in enumerate(paths)
        try
            # Safely extract node data
            if length(path.nodes) >= 3
                year_node = path.nodes[1]
                typical_day_node = path.nodes[2]
                hour_node = path.nodes[3]
                
                # Extract data safely with defaults and type conversion
                demand_growth = Float64(get(year_node.data, :demand_growth, 1.0))
                carbon_budget = Float64(get(year_node.data, :carbon_budget, 5000.0))
                carbon_price = Float64(get(year_node.data, :carbon_price, 50.0))
                
                day_type = string(get(typical_day_node.data, :day_type, "unknown"))
                
                electricity_load = Float64(get(hour_node.data, :electricity_load, 0.8))
                thermal_load = Float64(get(hour_node.data, :thermal_load, 0.6))
                solar_output = Float64(get(hour_node.data, :solar_output, 0.3))
                wind_output = Float64(get(hour_node.data, :wind_output, 0.5))
                
                year_idx = hasfield(typeof(year_node), :time_index) ? year_node.time_index : i
                hour_idx = hasfield(typeof(hour_node), :time_index) ? hour_node.time_index : (i % 24) + 1
                
                push!(scenario_data, [
                    i,
                    Float64(path.probability),
                    Int(year_idx),
                    day_type,
                    Int(hour_idx),
                    demand_growth,
                    carbon_budget,
                    carbon_price,
                    electricity_load,
                    thermal_load,
                    solar_output,
                    wind_output
                ])
            else
                println("Warning: Path $i has insufficient nodes ($(length(path.nodes)))")
            end
        catch e
            println("Warning: Error processing path $i: $e")
            # Add default row to maintain data integrity
            push!(scenario_data, [
                i, 1.0/length(paths), 1, "unknown", 1,
                1.0, 5000.0, 50.0, 0.8, 0.6, 0.3, 0.5
            ])
        end
    end
    
    println("Extracted data for $(nrow(scenario_data)) scenario paths")
    return scenario_data
end

"""
    create_technology_data()

Create technology parameter data for optimization.
"""
function create_technology_data()
    return Dict(
        "technologies" => [
            Dict("name" => "solar", "investment_cost" => 1000, "capacity_factor" => 0.2, 
                 "lifetime" => 25, "initial_capacity" => 0.0, "max_annual_investment" => 100.0),
            Dict("name" => "wind", "investment_cost" => 1200, "capacity_factor" => 0.3, 
                 "lifetime" => 20, "initial_capacity" => 0.0, "max_annual_investment" => 80.0),
            Dict("name" => "battery", "investment_cost" => 800, "capacity_factor" => 0.9, 
                 "lifetime" => 15, "initial_capacity" => 10.0, "max_annual_investment" => 50.0),
            Dict("name" => "electrolyzer", "investment_cost" => 1500, "capacity_factor" => 0.7, 
                 "lifetime" => 20, "initial_capacity" => 0.0, "max_annual_investment" => 30.0),
            Dict("name" => "fuel_cell", "investment_cost" => 1800, "capacity_factor" => 0.8, 
                 "lifetime" => 15, "initial_capacity" => 0.0, "max_annual_investment" => 25.0),
            Dict("name" => "heat_pump", "investment_cost" => 600, "capacity_factor" => 0.9, 
                 "lifetime" => 20, "initial_capacity" => 20.0, "max_annual_investment" => 40.0),
            Dict("name" => "CHP", "investment_cost" => 1000, "capacity_factor" => 0.8, 
                 "lifetime" => 25, "initial_capacity" => 15.0, "max_annual_investment" => 35.0)
        ]
    )
end

"""
    create_demand_data(tree, base_scenarios)

Create demand data from scenario tree and base scenarios.
"""
function create_demand_data(tree, base_scenarios)
    return Dict(
        "base_electricity_demand" => 100.0,  # MW
        "base_heat_demand" => 80.0,         # MW
        "base_hydrogen_demand" => 10.0,     # MW
        "demand_growth_rate" => 0.02,       # Annual growth
        "seasonal_factors" => Dict(
            "winter" => 1.2,
            "spring" => 1.0,
            "summer" => 0.8,
            "autumn" => 1.1
        )
    )
end

"""
    create_economic_data()

Create economic parameter data for optimization.
"""
function create_economic_data()
    return Dict(
        "discount_rate" => 0.05,
        "carbon_price_base" => 50.0,
        "load_shed_penalty" => 1000.0,
        "grid_price_base" => 0.12,
        "grid_sale_factor" => 0.8
    )
end
