# Scenario Export Module - Handle export of scenario trees and data

using CSV
using DataFrames
using Dates

# Try to include and use NestedScenarioTree module at top level
NESTED_TREE_AVAILABLE = false
try
    include("nested_scenario_tree.jl")
    using .NestedScenarioTree
    global NESTED_TREE_AVAILABLE = true
catch
    global NESTED_TREE_AVAILABLE = false
end

# Try to include tree_analysis module at top level
TREE_ANALYSIS_AVAILABLE = false
try
    include("tree_analysis.jl")
    global TREE_ANALYSIS_AVAILABLE = true
catch
    global TREE_ANALYSIS_AVAILABLE = false
end

"""
    export_scenario_tree(tree, base_scenarios, validation, output_dir::String)

Export the generated scenario tree structure and data to files.
"""
function export_scenario_tree(tree, base_scenarios, validation, output_dir::String)
    println("Exporting scenario tree to: $output_dir")
    
    # Create output directory
    mkpath(output_dir)
    
    try
        # 1. Export tree structure summary
        tree_summary = Dict(
            "structure" => Dict(
                "total_nodes" => tree !== nothing ? tree.total_nodes : 0,
                "total_paths" => tree !== nothing ? tree.total_paths : 0,
                "layers" => tree !== nothing ? tree.layers : [],
                "validation" => validation
            ),
            "generation_timestamp" => string(now()),
            "parameters" => Dict(
                "years" => 3,
                "weeks_per_year" => 4,
                "days_per_week" => 7,
                "hours_per_day" => 24
            )
        )
        
        # Save tree summary as JSON-like format
        open(joinpath(output_dir, "tree_summary.txt"), "w") do f
            for (key, value) in tree_summary
                println(f, "$key: $value")
            end
        end
        
        # 2. Export base scenarios
        if isa(base_scenarios, Dict)
            open(joinpath(output_dir, "base_scenarios.txt"), "w") do f
                println(f, "Base Scenarios Structure:")
                for (key, value) in base_scenarios
                    println(f, "Key: $key")
                    if isa(value, Dict)
                        for (subkey, subvalue) in value
                            println(f, "  $subkey: $subvalue")
                        end
                    else
                        println(f, "  Value: $value")
                    end
                    println(f, "")
                end
            end
        end
        
        # 3. Export scenario paths if tree is valid
        if tree !== nothing
            if NESTED_TREE_AVAILABLE
                try
                    paths = NestedScenarioTree.generate_scenario_paths(tree)
                    export_scenario_paths_three_layer(paths, joinpath(output_dir, "scenario_paths.csv"))
                catch e
                    println("Warning: Could not export scenario paths: $e")
                    # Export mock paths instead
                    mock_paths = create_mock_paths_three_layer(3, 4, 7)
                    export_scenario_paths_three_layer(mock_paths, joinpath(output_dir, "mock_scenario_paths.csv"))
                end
            else
                println("NestedScenarioTree module not available, exporting mock paths...")
                mock_paths = create_mock_paths_three_layer(3, 4, 7)
                export_scenario_paths_three_layer(mock_paths, joinpath(output_dir, "mock_scenario_paths.csv"))
            end
        else
            println("Tree is null, exporting mock paths...")
            mock_paths = create_mock_paths_three_layer(3, 4, 7)
            export_scenario_paths_three_layer(mock_paths, joinpath(output_dir, "mock_scenario_paths.csv"))
        end
        
        # 4. Export tree statistics
        if tree !== nothing
            export_tree_statistics(tree, joinpath(output_dir, "tree_statistics.csv"))
        end
        
        println("Scenario tree export completed successfully!")
        
    catch e
        println("Error exporting scenario tree: $e")
    end
end

"""
    export_scenario_paths_three_layer(paths, output_file::String)

Export three-layer scenario paths to CSV file.
"""
function export_scenario_paths_three_layer(paths, output_file::String)
    scenario_data = DataFrame(
        path_id = Int[],
        probability = Float64[],
        year = Int[],
        week = Int[],
        day = Int[],
        demand_growth = Float64[],
        carbon_budget = Float64[],
        carbon_price = Float64[],
        weekly_activity_factor = Float64[],
        day_type = String[],
        daily_factor = Float64[],
        electricity_load_avg = Float64[],
        thermal_load_avg = Float64[],
        solar_output_avg = Float64[],
        wind_output_avg = Float64[]
    )
    
    for (i, path) in enumerate(paths)
        try
            if length(path.nodes) >= 3
                year_node = path.nodes[1]
                week_node = path.nodes[2]
                day_node = path.nodes[3]
                
                # Extract data with safe defaults
                year_idx = hasfield(typeof(year_node), :time_index) ? year_node.time_index : 1
                week_idx = hasfield(typeof(week_node), :time_index) ? week_node.time_index : 1
                day_idx = hasfield(typeof(day_node), :time_index) ? day_node.time_index : 1
                
                demand_growth = Float64(get(year_node.data, :demand_growth, 1.0))
                carbon_budget = Float64(get(year_node.data, :carbon_budget, 5000.0))
                carbon_price = Float64(get(year_node.data, :carbon_price, 50.0))
                
                weekly_activity_factor = Float64(get(week_node.data, :weekly_activity_factor, 1.0))
                
                day_type = string(get(day_node.data, :day_type, "weekday"))
                daily_factor = Float64(get(day_node.data, :daily_factor, 1.0))
                
                # Average daily values (since hours are fixed at 24)
                electricity_load_avg = Float64(get(day_node.data, :electricity_load_avg, 0.8))
                thermal_load_avg = Float64(get(day_node.data, :thermal_load_avg, 0.6))
                solar_output_avg = Float64(get(day_node.data, :solar_output_avg, 0.3))
                wind_output_avg = Float64(get(day_node.data, :wind_output_avg, 0.5))
                
                push!(scenario_data, [
                    i, Float64(path.probability), Int(year_idx), Int(week_idx), Int(day_idx),
                    demand_growth, carbon_budget, carbon_price,
                    weekly_activity_factor, day_type, daily_factor,
                    electricity_load_avg, thermal_load_avg, solar_output_avg, wind_output_avg
                ])
            end
        catch e
            println("Warning: Error processing path $i for export: $e")
        end
    end
    
    CSV.write(output_file, scenario_data)
    println("Exported $(nrow(scenario_data)) three-layer scenario paths to: $output_file")
end

"""
    export_tree_statistics(tree, output_file::String)

Export tree structure statistics to CSV file.
"""
function export_tree_statistics(tree, output_file::String)
    if TREE_ANALYSIS_AVAILABLE
        try
            layer_counts, paths = analyze_tree_structure(tree)
            
            stats_data = DataFrame(
                layer = String[],
                node_count = Int[],
                description = String[]
            )
            
            for layer in tree.layers
                count = get(layer_counts, layer, 0)
                description = get(Dict(
                    :year => "Strategic planning horizon",
                    :week => "Weekly operational patterns",
                    :day => "Daily operational cycles"
                ), layer, "")
                
                push!(stats_data, [string(layer), count, description])
            end
            
            # Add summary statistics
            push!(stats_data, ["TOTAL_PATHS", length(paths), "Total scenario paths generated"])
            push!(stats_data, ["TOTAL_NODES", tree.total_nodes, "Total nodes in the tree"])
            
            CSV.write(output_file, stats_data)
            println("Exported tree statistics to: $output_file")
            
        catch e
            println("Warning: Could not export tree statistics: $e")
        end
    else
        println("Warning: Tree analysis module not available")
    end
end

"""
    create_mock_paths_three_layer(years::Int, weeks::Int, days::Int)

Create mock scenario paths for testing when real tree generation fails.
"""
function create_mock_paths_three_layer(years::Int, weeks::Int, days::Int)
    # Create a simple mock path structure
    mock_paths = []
    path_id = 1
    
    for year in 1:years
        for week in 1:weeks
            for day in 1:days
                # Create mock path with required structure
                mock_path = (
                    nodes = [
                        (time_index = year, data = Dict(:demand_growth => 1.0 + 0.02*year, :carbon_budget => 5000.0, :carbon_price => 50.0)),
                        (time_index = week, data = Dict(:weekly_activity_factor => 0.9 + 0.1*week/weeks)),
                        (time_index = day, data = Dict(:day_type => day <= 5 ? "weekday" : "weekend", :daily_factor => 1.0, 
                                                     :electricity_load_avg => 0.8, :thermal_load_avg => 0.6, 
                                                     :solar_output_avg => 0.3, :wind_output_avg => 0.5))
                    ],
                    probability = 1.0 / (years * weeks * days)
                )
                push!(mock_paths, mock_path)
                path_id += 1
            end
        end
    end
    
    return mock_paths
end
