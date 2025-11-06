# lifecycle_analysis_engine.jl
# Core analysis engine for lifecycle simulation

"""
    LifeCycleAnalysisEngine

Core analysis engine module for lifecycle simulation processing.
"""
module LifeCycleAnalysisEngine

using ..LifeCycleConfig
export run_tree_construction, run_analysis_pipeline, run_comprehensive_analysis

"""
    run_tree_construction(config::Dict)

Build scenario tree based on configuration.
"""
function run_tree_construction(config::Dict)
    println("=== Building Three-Layer Scenario Tree ===")
    
    years = config["years"]
    weeks_per_year = config["weeks_per_year"] 
    days_per_week = config["days_per_week"]
    
    tree = nothing
    base_scenarios = Dict()
    validation = Dict()
    
    try
        # Try primary tree construction method
        include("tree_construction.jl")
        tree, base_scenarios, validation = build_lifecycle_nested_tree(years, weeks_per_year, days_per_week)
    catch e
        println("Warning: Primary tree construction failed: $e")
        try
            # Fallback to alternative method
            tree, base_scenarios, validation = build_lifecycle_nested_tree_fallback(years, weeks_per_year, days_per_week)
        catch e2
            println("Warning: Fallback tree construction also failed: $e2")
        end
    end
    
    return tree, base_scenarios, validation
end

"""
    run_analysis_pipeline(tree, base_scenarios, config::Dict)

Run the complete analysis pipeline.
"""
function run_analysis_pipeline(tree, base_scenarios, config::Dict)
    results = Dict()
    
    # Step 1: Export scenario tree
    println("=== Exporting Scenario Tree ===")
    try
        export_scenario_tree(tree, base_scenarios, Dict(), config["output_dirs"]["export"])
        results["export_status"] = "success"
    catch e
        println("Warning: Scenario export failed: $e")
        results["export_status"] = "failed"
    end
    
    # Step 2: Analyze tree structure
    println("=== Analyzing Tree Structure ===")
    layer_counts, paths = analyze_tree_structure(tree)
    scenario_data = extract_scenario_data_three_layer(paths)
    
    if isempty(paths)
        println("No valid paths found, creating mock paths...")
        include("mock_scenario_generator.jl")
        paths = create_mock_paths_three_layer(config["years"], config["weeks_per_year"], config["days_per_week"])
        scenario_data = extract_scenario_data_three_layer(paths)
    end
    
    results["paths"] = paths
    results["scenario_data"] = scenario_data
    
    # Step 3: Visualization
    println("=== Visualizing Results ===")
    try
        visualize_nested_tree_three_layer(tree, config["output_dirs"]["results"])
        results["visualization_status"] = "success"
    catch e
        println("Warning: Visualization failed: $e")
        results["visualization_status"] = "failed"
    end
    
    return results
end

"""
    run_comprehensive_analysis(config::Dict)

Run comprehensive lifecycle analysis including optimization and stochastic analysis.
"""
function run_comprehensive_analysis(config::Dict)
    println("=== Running Comprehensive Lifecycle Analysis ===")
    
    years = config["years"]
    weeks_per_year = config["weeks_per_year"]
    days_per_week = config["days_per_week"]
    
    results = Dict()
    
    # Lifecycle optimization
    try
        tree_analysis, paths_analysis, optimization_results, solution_analysis, cost_breakdown = 
            run_complete_lifecycle_analysis_three_layer(years, weeks_per_year, days_per_week)
        
        results["optimization"] = optimization_results
        results["solution_analysis"] = solution_analysis
        results["cost_breakdown"] = cost_breakdown
    catch e
        println("Warning: Lifecycle optimization failed: $e")
        results["optimization"] = nothing
        results["solution_analysis"] = nothing
    end
    
    # Sensitivity analysis
    try
        sensitivity_results = run_sensitivity_analysis(years, weeks_per_year, days_per_week)
        results["sensitivity"] = sensitivity_results
        println("Sensitivity Analysis completed with $(length(sensitivity_results)) parameters analyzed.")
    catch e
        println("Warning: Sensitivity analysis failed: $e")
        results["sensitivity"] = Dict()
    end
    
    return results
end

end # module
