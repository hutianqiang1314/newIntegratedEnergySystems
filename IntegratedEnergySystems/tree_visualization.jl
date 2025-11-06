# Tree Visualization Module - handles plotting and visualization of trees and data

using Plots
using DataFrames
using CSV
using Statistics

"""
    visualize_nested_tree(tree, output_dir::String="results")

Visualize the nested scenario tree structure and key scenarios.
"""
function visualize_nested_tree(tree, output_dir::String="results")
    println("\n=== Tree Visualization ===")
    
    # Create output directory
    mkpath(output_dir)
    
    # 1. Tree structure visualization
    plot_tree_structure(tree, joinpath(output_dir, "tree_structure.png"))
    
    # 2. Generate and plot scenario paths
    paths = NestedScenarioTree.generate_scenario_paths(tree)
    scenario_data = extract_scenario_data(paths)
    
    # 3. Plot probability distribution
    plot_probability_distribution(paths, joinpath(output_dir, "probability_distribution.png"))
    
    # 4. Plot scenario characteristics
    plot_scenario_characteristics(scenario_data, output_dir)
    
    # 5. Save scenario data
    CSV.write(joinpath(output_dir, "scenario_data.csv"), scenario_data)
    
    println("Visualization completed. Results saved to: $output_dir")
end

"""
    plot_tree_structure(tree, output_file::String)

Plot the hierarchical structure of the nested scenario tree.
"""
function plot_tree_structure(tree, output_file::String)
    # Collect node positions for plotting
    node_positions = Dict{Int, Tuple{Float64, Float64}}()
    edges = Vector{Tuple{Int, Int}}()
    
    # Recursive function to assign positions
    function assign_positions(node, layer, position_in_layer, layer_width)
        x = layer
        y = position_in_layer - layer_width / 2
        node_positions[node.id] = (x, y)
        
        child_positions = collect(1:length(node.children))
        for (i, child) in enumerate(node.children)
            push!(edges, (node.id, child.id))
            assign_positions(child, layer + 1, child_positions[i], length(node.children))
        end
    end
    
    # Assign positions starting from root nodes
    for (i, root) in enumerate(tree.root_nodes)
        assign_positions(root, 1, i, length(tree.root_nodes))
    end
    
    # Create plot
    plt = plot(
        title="Nested Scenario Tree Structure",
        xlabel="Time Layer",
        ylabel="Node Position",
        legend=false,
        size=(800, 600)
    )
    
    # Plot edges
    for (src_id, dst_id) in edges
        src_pos = node_positions[src_id]
        dst_pos = node_positions[dst_id]
        plot!([src_pos[1], dst_pos[1]], [src_pos[2], dst_pos[2]], 
              color=:gray, alpha=0.6, linewidth=1)
    end
    
    # Plot nodes with different colors for each layer
    layer_colors = [:red, :blue, :green, :orange, :purple]
    for (node_id, (x, y)) in node_positions
        layer_idx = Int(x)
        color = layer_colors[min(layer_idx, length(layer_colors))]
        scatter!([x], [y], color=color, markersize=4)
    end
    
    # Add layer labels
    for (i, layer) in enumerate(tree.layers)
        annotate!(i, minimum([pos[2] for pos in values(node_positions)]) - 1, 
                 text(string(layer), 10, :center))
    end
    
    savefig(plt, output_file)
    println("Tree structure plot saved to: $output_file")
end

"""
    plot_probability_distribution(paths, output_file::String)

Plot the probability distribution of scenario paths.
"""
function plot_probability_distribution(paths, output_file::String)
    probabilities = [path.probability for path in paths]
    
    plt = histogram(
        probabilities,
        bins=20,
        title="Scenario Path Probability Distribution",
        xlabel="Probability",
        ylabel="Number of Paths",
        legend=false,
        size=(800, 500)
    )
    
    # Add statistics
    mean_prob = mean(probabilities)
    vline!([mean_prob], color=:red, linewidth=2, linestyle=:dash, 
           label="Mean: $(round(mean_prob, digits=4))")
    
    savefig(plt, output_file)
    println("Probability distribution plot saved to: $output_file")
end

"""
    plot_scenario_characteristics(scenario_data::DataFrame, output_dir::String)

Plot various characteristics of the scenarios.
"""
function plot_scenario_characteristics(scenario_data::DataFrame, output_dir::String)
    # 1. Demand growth by year
    plt1 = scatter(
        scenario_data.year,
        scenario_data.demand_growth,
        title="Demand Growth by Year",
        xlabel="Year",
        ylabel="Demand Growth Factor",
        legend=false,
        size=(600, 400)
    )
    savefig(plt1, joinpath(output_dir, "demand_growth_by_year.png"))
    
    # 2. Carbon budget and price correlation
    plt2 = scatter(
        scenario_data.carbon_budget,
        scenario_data.carbon_price,
        title="Carbon Budget vs Carbon Price",
        xlabel="Carbon Budget",
        ylabel="Carbon Price",
        legend=false,
        size=(600, 400)
    )
    savefig(plt2, joinpath(output_dir, "carbon_budget_vs_price.png"))
    
    # 3. Renewable energy output by typical day
    unique_days = unique(scenario_data.typical_day)
    solar_means = [mean(scenario_data[scenario_data.typical_day .== day, :solar_output]) for day in unique_days]
    wind_means = [mean(scenario_data[scenario_data.typical_day .== day, :wind_output]) for day in unique_days]
    
    plt3 = plot(
        title="Renewable Energy Output by Typical Day",
        xlabel="Typical Day Type",
        ylabel="Normalized Output",
        size=(800, 500),
        legend=:outertopright
    )
    
    bar!(plt3, 1:length(unique_days), solar_means, alpha=0.7, label="Solar", color=:orange)
    bar!(plt3, 1:length(unique_days), wind_means, alpha=0.7, label="Wind", color=:blue)
    plot!(plt3, xticks=(1:length(unique_days), unique_days), xrotation=45)
    
    savefig(plt3, joinpath(output_dir, "renewable_output_by_day.png"))
    
    # 4. Load profile by hour
    plt4 = plot(
        scenario_data.hour,
        [scenario_data.electricity_load scenario_data.thermal_load],
        title="Load Profile by Hour",
        xlabel="Hour",
        ylabel="Normalized Load",
        label=["Electricity" "Thermal"],
        linewidth=2,
        size=(600, 400)
    )
    savefig(plt4, joinpath(output_dir, "load_profile_by_hour.png"))
    
    println("Scenario characteristic plots saved to: $output_dir")
end

"""
    visualize_optimization_results(optimization_results, solution_analysis, cost_breakdown, output_dir)

Visualize optimization results including investments and operations.
"""
function visualize_optimization_results(optimization_results, solution_analysis, cost_breakdown, output_dir)
    try
        mkpath(output_dir)
        
        # Check if solution_analysis exists and has required data
        if solution_analysis !== nothing && haskey(solution_analysis, "investment_by_technology")
            # Plot 1: Investment decisions by technology
            tech_names = collect(keys(solution_analysis["investment_by_technology"]))
            investments = [solution_analysis["investment_by_technology"][tech] for tech in tech_names]
            
            if !isempty(tech_names) && !isempty(investments)
                p1 = bar(tech_names, investments,
                        title="Investment by Technology",
                        xlabel="Technology",
                        ylabel="Total Investment (MW)",
                        legend=false,
                        xrotation=45,
                        size=(800, 500))
                savefig(p1, joinpath(output_dir, "investments_by_technology.png"))
            end
        end
        
        # Plot 2: Cost breakdown
        if cost_breakdown !== nothing && !isempty(cost_breakdown)
            cost_categories = collect(keys(cost_breakdown))
            cost_values = [cost_breakdown[cat] for cat in cost_categories]
            
            if !isempty(cost_categories) && all(v -> v >= 0, cost_values)
                try
                    p2 = pie(cost_categories, cost_values,
                            title="Lifecycle Cost Breakdown",
                            size=(600, 600))
                    savefig(p2, joinpath(output_dir, "cost_breakdown.png"))
                catch e
                    println("Warning: Could not create pie chart: $e")
                    # Create bar chart instead
                    p2_alt = bar(cost_categories, cost_values,
                               title="Lifecycle Cost Breakdown",
                               xlabel="Cost Category",
                               ylabel="Cost",
                               legend=false,
                               xrotation=45,
                               size=(800, 500))
                    savefig(p2_alt, joinpath(output_dir, "cost_breakdown_bar.png"))
                end
            end
        end
        
        # Plot 3: Key performance indicators
        if solution_analysis !== nothing
            kpis = ["total_investment_MW", "renewable_share", "total_carbon_emissions"]
            kpi_values = []
            kpi_labels = []
            
            for kpi in kpis
                if haskey(solution_analysis, kpi)
                    push!(kpi_values, Float64(solution_analysis[kpi]))
                    if kpi == "total_investment_MW"
                        push!(kpi_labels, "Total Investment (MW)")
                    elseif kpi == "renewable_share" 
                        push!(kpi_labels, "Renewable Share")
                    else
                        push!(kpi_labels, "Carbon Emissions (kg)")
                    end
                end
            end
            
            if !isempty(kpi_values)
                p3 = bar(kpi_labels, kpi_values,
                        title="Key Performance Indicators",
                        xlabel="Indicator",
                        ylabel="Value",
                        legend=false,
                        xrotation=45,
                        size=(800, 500))
                savefig(p3, joinpath(output_dir, "key_performance_indicators.png"))
            end
        end
        
        # Save results to CSV
        if solution_analysis !== nothing
            try
                results_df = DataFrame(
                    Metric = collect(keys(solution_analysis)),
                    Value = [string(v) for v in values(solution_analysis)]
                )
                CSV.write(joinpath(output_dir, "solution_analysis.csv"), results_df)
            catch e
                println("Warning: Could not save solution analysis CSV: $e")
            end
        end
        
        if cost_breakdown !== nothing
            try
                costs_df = DataFrame(
                    Cost_Category = collect(keys(cost_breakdown)),
                    Cost = collect(values(cost_breakdown))
                )
                CSV.write(joinpath(output_dir, "cost_breakdown.csv"), costs_df)
            catch e
                println("Warning: Could not save cost breakdown CSV: $e")
            end
        end
        
        println("Optimization visualization completed. Results saved to: $output_dir")
    catch e
        println("Error in visualization: $e")
    end
end

"""
    visualize_sensitivity_analysis(sensitivity_results, output_dir)

Visualize sensitivity analysis results.
"""
function visualize_sensitivity_analysis(sensitivity_results, output_dir)
    mkpath(output_dir)
    
    for (param_name, param_results) in sensitivity_results
        if isempty(param_results)
            continue
        end
        
        param_values = [r["parameter_value"] for r in param_results]
        objective_values = [r["objective_value"] for r in param_results]
        investments = [r["total_investment"] for r in param_results]
        renewable_shares = [r["renewable_share"] for r in param_results]
        
        # Plot objective value sensitivity
        p1 = plot(param_values, objective_values,
                 title="Objective Value Sensitivity to $param_name",
                 xlabel="$param_name",
                 ylabel="Total Cost",
                 marker=:circle,
                 linewidth=2,
                 size=(800, 500))
        savefig(p1, joinpath(output_dir, "$(param_name)_objective_sensitivity.png"))
        
        # Plot investment sensitivity
        p2 = plot(param_values, investments,
                 title="Investment Sensitivity to $param_name",
                 xlabel="$param_name",
                 ylabel="Total Investment (MW)",
                 marker=:circle,
                 linewidth=2,
                 size=(800, 500))
        savefig(p2, joinpath(output_dir, "$(param_name)_investment_sensitivity.png"))
        
        # Plot renewable share sensitivity
        p3 = plot(param_values, renewable_shares,
                 title="Renewable Share Sensitivity to $param_name",
                 xlabel="$param_name",
                 ylabel="Renewable Share",
                 marker=:circle,
                 linewidth=2,
                 size=(800, 500))
        savefig(p3, joinpath(output_dir, "$(param_name)_renewable_sensitivity.png"))
        
        # Save data to CSV
        sensitivity_df = DataFrame(param_results)
        CSV.write(joinpath(output_dir, "$(param_name)_sensitivity_data.csv"), sensitivity_df)
    end
    
    println("Sensitivity analysis visualization completed. Results saved to: $output_dir")
end
