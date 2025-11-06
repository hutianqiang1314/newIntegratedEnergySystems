# Result Display Module - Functions for displaying and visualizing results

using Plots
using DataFrames

"""
    display_results_summary(paths, scenario_data, optimization_results, solution_analysis, sensitivity_results, strategy_comparison)

Display comprehensive results summary.
"""
function display_results_summary(paths, scenario_data, optimization_results, solution_analysis, sensitivity_results, strategy_comparison)
    println("\n=== Comprehensive Results Summary ===")
    
    println("Scenario Analysis:")
    println("  - Total scenario paths: $(length(paths))")
    println("  - Scenario data points: $(nrow(scenario_data))")
    
    if optimization_results !== nothing
        println("Optimization Results:")
        for (key, value) in optimization_results
            println("  - $key: $value")
        end
    end
    
    if solution_analysis !== nothing
        println("Solution Analysis:")
        for (key, value) in solution_analysis
            println("  - $key: $value")
        end
    end
    
    # Fix the sensitivity results display - check if it's a dictionary first
    if isa(sensitivity_results, Dict) && !isempty(sensitivity_results)
        println("Sensitivity Analysis:")
        for (param, result) in sensitivity_results
            if isa(result, Dict)
                sensitivity_value = get(result, "sensitivity", "N/A")
                println("  - $param: sensitivity = $sensitivity_value")
            else
                println("  - $param: $result")
            end
        end
    else
        println("Sensitivity Analysis: No results available")
    end
    
    # Fix the strategy comparison display - check if it's a dictionary first
    if isa(strategy_comparison, Dict) && !isempty(strategy_comparison)
        println("Strategy Comparison:")
        for (strategy, result) in strategy_comparison
            println("  - $strategy: completed")
        end
    else
        println("Strategy Comparison: No results available")
    end
end

"""
    plot_mock_scenario_characteristics(scenario_data::DataFrame, output_dir::String)

Plot basic characteristics of mock scenario data.
"""
function plot_mock_scenario_characteristics(scenario_data::DataFrame, output_dir::String)
    mkpath(output_dir)
    
    try
        # Plot carbon budget over time
        if "carbon_budget" in names(scenario_data) && "year" in names(scenario_data)
            p1 = plot(scenario_data.year, scenario_data.carbon_budget,
                     title="Carbon Budget Over Years",
                     xlabel="Year", ylabel="Carbon Budget",
                     marker=:circle, linewidth=2)
            savefig(p1, joinpath(output_dir, "carbon_budget.png"))
        end
        
        # Plot carbon price over time
        if "carbon_price" in names(scenario_data) && "year" in names(scenario_data)
            p2 = plot(scenario_data.year, scenario_data.carbon_price,
                     title="Carbon Price Over Years",
                     xlabel="Year", ylabel="Carbon Price",
                     marker=:circle, linewidth=2)
            savefig(p2, joinpath(output_dir, "carbon_price.png"))
        end
        
        println("Mock scenario characteristics plots saved to: $output_dir")
        
    catch e
        println("Warning: Error creating plots: $e")
    end
end

"""
    display_mock_results_summary(paths, scenario_data, base_scenarios)

Display summary of mock analysis results.
"""
function display_mock_results_summary(paths, scenario_data, base_scenarios)
    println("\n=== Mock Results Summary ===")
    println("Number of scenario paths: $(length(paths))")
    println("Scenario data rows: $(nrow(scenario_data))")
    
    if nrow(scenario_data) > 0
        if "carbon_budget" in names(scenario_data)
            println("Carbon budget range: $(minimum(scenario_data.carbon_budget)) - $(maximum(scenario_data.carbon_budget))")
        end
        if "carbon_price" in names(scenario_data)
            println("Carbon price range: $(minimum(scenario_data.carbon_price)) - $(maximum(scenario_data.carbon_price))")
        end
    end
    
    println("Base scenarios keys: $(collect(keys(base_scenarios)))")
end

"""
    visualize_nested_tree(tree, output_dir::String="results")

Visualize the nested scenario tree structure.
"""
function visualize_nested_tree(tree, output_dir::String="results")
    mkpath(output_dir)
    
    try
        if tree !== nothing
            println("Tree visualization: $(tree.layers) layers")
            println("Total nodes: $(tree.total_nodes)")
            println("Total paths: $(tree.total_paths)")
            
            # Create a simple text summary
            open(joinpath(output_dir, "tree_structure.txt"), "w") do f
                println(f, "Nested Scenario Tree Structure")
                println(f, "Layers: $(tree.layers)")
                println(f, "Total nodes: $(tree.total_nodes)")
                println(f, "Total paths: $(tree.total_paths)")
            end
        else
            println("No tree available for visualization")
        end
        
    catch e
        println("Warning: Tree visualization failed: $e")
    end
end

"""
    plot_mock_scenario_characteristics_three_layer(scenario_data::DataFrame, output_dir::String)

Plot basic characteristics of three-layer mock scenario data.
"""
function plot_mock_scenario_characteristics_three_layer(scenario_data::DataFrame, output_dir::String)
    plot_mock_scenario_characteristics(scenario_data, output_dir)  # Use existing function as base
    # Additional three-layer specific plots can be added here
end

"""
    display_mock_results_summary_three_layer(paths, scenario_data, base_scenarios)

Display summary of three-layer mock analysis results.
"""
function display_mock_results_summary_three_layer(paths, scenario_data, base_scenarios)
    display_mock_results_summary(paths, scenario_data, base_scenarios)  # Use existing function as base
    # Additional three-layer specific summary can be added here
end

"""
    visualize_nested_tree_three_layer(tree, output_dir::String="results")

Visualize the three-layer nested scenario tree structure.
"""
function visualize_nested_tree_three_layer(tree, output_dir::String="results")
    visualize_nested_tree(tree, output_dir)  # Use existing function as base
    # Additional three-layer specific visualization can be added here
end
