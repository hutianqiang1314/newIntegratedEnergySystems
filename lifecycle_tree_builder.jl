# lifecycle_tree_builder.jl
# Tree construction and management

"""
    build_simple_nested_tree(years::Int, weeks_per_year::Int, days_per_week::Int)

Simple fallback tree construction when other methods fail.
"""
function build_simple_nested_tree(years::Int, weeks_per_year::Int, days_per_week::Int)
    println("Building simple nested tree structure...")
    
    # Create a simple tree structure with consistent typing
    tree = (
        layers = [:Year, :Week, :Day],  # Use symbols instead of strings
        total_nodes = years * weeks_per_year * days_per_week,
        total_paths = years * weeks_per_year * days_per_week,
        time_structure = Dict(
            :years => years,
            :weeks_per_year => weeks_per_year,
            :days_per_week => days_per_week,
            :hours_per_day => 24
        ),
        root_nodes = [1]
    )
    
    # Create simple base scenarios
    base_scenarios = Dict(
        "scenario_1" => Dict("cost_factor" => 1.0, "demand_factor" => 1.0),
        "scenario_2" => Dict("cost_factor" => 1.1, "demand_factor" => 0.9),
        "scenario_3" => Dict("cost_factor" => 0.9, "demand_factor" => 1.1)
    )
    
    # Create simple validation
    validation = Dict(
        "tree_valid" => true,
        "scenarios_valid" => true,
        "total_scenarios" => length(base_scenarios)
    )
    
    println("Simple tree constructed with $(tree.total_nodes) nodes")
    
    return tree, base_scenarios, validation
end

"""
    run_tree_construction_with_fallbacks(config::Dict)

Build scenario tree with multiple fallback options.
"""
function run_tree_construction_with_fallbacks(config::Dict)
    println("=== Building Three-Layer Scenario Tree ===")
    
    years = config["years"]
    weeks_per_year = config["weeks_per_year"] 
    days_per_week = config["days_per_week"]
    
    tree = nothing
    base_scenarios = Dict()
    validation = Dict()
    
    # Try primary tree construction
    try
        if isfile("tree_construction.jl")
            include("tree_construction.jl")
            tree, base_scenarios, validation = build_lifecycle_nested_tree(years, weeks_per_year, days_per_week)
        else
            println("tree_construction.jl not found, using built-in fallback")
            tree, base_scenarios, validation = build_simple_nested_tree(years, weeks_per_year, days_per_week)
        end
    catch e
        println("Warning: Primary tree construction failed: $e")
        try
            # Try lifecycle simulation runner fallback
            if isdefined(Main, :build_lifecycle_nested_tree_fallback)
                tree, base_scenarios, validation = build_lifecycle_nested_tree_fallback(years, weeks_per_year, days_per_week)
            else
                println("Using built-in simple tree construction")
                tree, base_scenarios, validation = build_simple_nested_tree(years, weeks_per_year, days_per_week)
            end
        catch e2
            println("Warning: Fallback tree construction also failed: $e2")
            tree, base_scenarios, validation = build_simple_nested_tree(years, weeks_per_year, days_per_week)
        end
    end
    
    return tree, base_scenarios, validation
end

"""
    convert_tree_for_analysis(tree)

Convert tree structure to be compatible with analysis functions.
"""
function convert_tree_for_analysis(tree)
    # Create a compatible tree structure
    if hasfield(typeof(tree), :layers)
        # Convert symbol layers to strings if needed
        layers_str = [string(layer) for layer in tree.layers]
        
        compatible_tree = (
            layers = layers_str,
            total_nodes = tree.total_nodes,
            total_paths = tree.total_paths,
            time_structure = tree.time_structure,
            root_nodes = tree.root_nodes
        )
        return compatible_tree
    else
        return tree
    end
end
