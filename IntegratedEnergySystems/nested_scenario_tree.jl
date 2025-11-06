# Nested Scenario Tree Construction for Life Cycle Integrated Energy System Simulation

module NestedScenarioTree

export ScenarioNode, NestedScenarioTreeType, ScenarioPath, build_nested_scenario_tree, 
       generate_scenario_paths, sample_conditional_data, reduce_scenario_tree, validate_tree_quality

using Random, Statistics, Distributions, LinearAlgebra

# ========== Core Data Structures ==========

mutable struct ScenarioNode
    id::Int
    time_scale::Symbol
    time_index::Int
    parent::Union{ScenarioNode, Nothing}
    children::Vector{ScenarioNode}
    probability::Float64
    conditional_probability::Float64
    data::Dict{Symbol, Any}
end

struct NestedScenarioTreeType
    root_nodes::Vector{ScenarioNode}
    layers::Vector{Symbol}
    time_structure::Dict{Symbol, Int}
    total_nodes::Int
    total_paths::Int
    creation_timestamp::Float64
end

struct ScenarioPath
    nodes::Vector{ScenarioNode}
    probability::Float64
    path_id::Int
end

# ========== Utility Functions ==========

let _id_counter = Ref(0)
    global function generate_unique_id()
        _id_counter[] += 1
        return _id_counter[]
    end
end

function reset_id_counter()
    global _id_counter = Ref(0)
end

# ========== Probability Management ==========

function compute_conditional_probability(parent::Union{ScenarioNode, Nothing}, time_scale::Symbol, 
                                       base_parameters::Dict{Symbol, Any}, index::Int)
    if parent === nothing
        # Root nodes: equal probability
        if haskey(base_parameters, :time_structure)
            return 1.0 / base_parameters[:time_structure][:years]
        else
            return 1.0
        end
    else
        # Child nodes: conditional on parent
        if time_scale == :typical_day
            if haskey(base_parameters, :typical_day_weights)
                weights = base_parameters[:typical_day_weights]
                if haskey(base_parameters, :time_indices)
                    day_types = base_parameters[:time_indices]["typical_day_types"]
                    if index <= length(day_types)
                        day_type = day_types[index]
                        total_weight = sum(values(weights))
                        return get(weights, day_type, 365.0/length(day_types)) / total_weight
                    end
                end
            end
            # Default uniform distribution
            n_days = haskey(base_parameters, :time_structure) ? base_parameters[:time_structure][:typical_days] : 4
            return 1.0 / n_days
        elseif time_scale == :hour
            n_hours = haskey(base_parameters, :time_structure) ? base_parameters[:time_structure][:hours_per_day] : 24
            return 1.0 / n_hours
        else
            return 1.0
        end
    end
end

function normalize_tree_probabilities!(tree::NestedScenarioTreeType)
    """Normalize probabilities to ensure all scenario paths sum to 1.0"""
    
    function update_node_probability!(node::ScenarioNode, parent_prob::Float64)
        if node.parent === nothing
            # Root node: use conditional probability as absolute probability
            node.probability = node.conditional_probability
        else
            # Child node: probability = parent_probability × conditional_probability
            node.probability = parent_prob * node.conditional_probability
        end
        
        # Recursively update children
        for child in node.children
            update_node_probability!(child, node.probability)
        end
    end
    
    # Update all nodes starting from roots
    for root in tree.root_nodes
        update_node_probability!(root, 1.0)
    end
    
    return tree
end

# ========== Scenario Data Generation ==========

function sample_conditional_data(parent::Union{ScenarioNode, Nothing}, time_scale::Symbol, 
                                base_parameters::Dict{Symbol, Any}, idx::Int)
    data = Dict{Symbol, Any}()
    
    if time_scale == :year
        # Annual parameters
        y = idx
        if haskey(base_parameters, :annual_data)
            annual_data = base_parameters[:annual_data]
            data[:demand_growth] = safe_get_array(annual_data, "electricity_load_factors", y, 1.0)
            data[:carbon_budget] = safe_get_array(annual_data, "carbon_budget", y, 5000.0)
            data[:carbon_price] = safe_get_array(annual_data, "carbon_price", y, 50.0)
        else
            # Stochastic generation with trends
            base_growth = 1.0 + 0.02 * (y - 1)
            data[:demand_growth] = base_growth * (1 + 0.1 * randn())
            
            base_budget = 5000.0 * (1.0 - 0.05 * (y - 1))
            data[:carbon_budget] = max(1000.0, base_budget * (1 + 0.15 * randn()))
            
            base_price = 50.0 * (1.0 + 0.05 * (y - 1))
            data[:carbon_price] = max(10.0, base_price * (1 + 0.2 * randn()))
        end
        
    elseif time_scale == :typical_day
        # Typical day parameters
        if haskey(base_parameters, :time_indices)
            day_types = base_parameters[:time_indices]["typical_day_types"]
            day_type = day_types[min(idx, length(day_types))]
            data[:day_type] = day_type
            
            # Get day-specific profiles
            if haskey(base_parameters, :typical_days_data) && haskey(base_parameters[:typical_days_data], day_type)
                day_data = base_parameters[:typical_days_data][day_type]
                data[:electricity_load] = get(day_data, "electricity_load", generate_load_profile("electricity", day_type))
                data[:thermal_load] = get(day_data, "thermal_load", generate_load_profile("thermal", day_type))
                data[:solar_output] = get(day_data, "solar_output", generate_renewable_profile("solar", day_type))
                data[:wind_output] = get(day_data, "wind_output", generate_renewable_profile("wind", day_type))
            else
                # Generate stochastic profiles
                data[:electricity_load] = generate_load_profile("electricity", "default")
                data[:thermal_load] = generate_load_profile("thermal", "default")
                data[:solar_output] = generate_renewable_profile("solar", "default")
                data[:wind_output] = generate_renewable_profile("wind", "default")
            end
            
            # Weight from parent year conditions
            if parent !== nothing
                seasonal_factor = get_seasonal_factor(day_type, parent.data)
                for key in [:electricity_load, :thermal_load]
                    if haskey(data, key)
                        data[key] = data[key] .* seasonal_factor
                    end
                end
            end
        else
            # Default generation
            data[:day_type] = "day_$idx"
            data[:electricity_load] = fill(0.8, 24)
            data[:thermal_load] = fill(0.6, 24)
            data[:solar_output] = fill(0.3, 24)
            data[:wind_output] = fill(0.5, 24)
        end
        
    elseif time_scale == :hour
        # Hourly parameters from parent typical day
        if parent !== nothing && haskey(parent.data, :electricity_load)
            data[:hour_index] = idx
            
            # Extract hourly values from parent profiles
            profiles = [:electricity_load, :thermal_load, :solar_output, :wind_output]
            for profile in profiles
                if haskey(parent.data, profile)
                    parent_profile = parent.data[profile]
                    if length(parent_profile) >= idx
                        # Add hour-specific stochastic variation
                        base_value = parent_profile[idx]
                        variation = 1.0 + 0.05 * randn()  # ±5% variation
                        data[profile] = max(0.0, base_value * variation)
                    else
                        data[profile] = 0.5  # Default value
                    end
                end
            end
            
            # Add correlations between variables
            if haskey(data, :electricity_load) && haskey(data, :thermal_load)
                # Thermal load correlates with electricity load
                correlation = 0.3
                data[:thermal_load] = data[:thermal_load] * (1 + correlation * (data[:electricity_load] - 0.8))
            end
        else
            # Default hourly values
            data[:hour_index] = idx
            data[:electricity_load] = 0.8 + 0.1 * randn()
            data[:thermal_load] = 0.6 + 0.1 * randn()
            data[:solar_output] = max(0.0, 0.3 + 0.2 * randn())
            data[:wind_output] = max(0.0, 0.5 + 0.3 * randn())
        end
    end
    
    return data
end

# Helper functions for profile generation
function safe_get_array(dict, key, index, default)
    if haskey(dict, key)
        arr = dict[key]
        return index <= length(arr) ? arr[index] : default
    else
        return default
    end
end

function generate_load_profile(load_type::String, day_type::String)
    hours = 24
    if load_type == "electricity"
        if occursin("winter", day_type)
            base_profile = [0.65, 0.60, 0.55, 0.55, 0.60, 0.70, 0.85, 1.00, 1.00, 0.95, 
                           0.90, 0.90, 0.85, 0.85, 0.90, 0.95, 1.00, 1.00, 0.95, 0.90, 
                           0.85, 0.80, 0.75, 0.70]
        elseif occursin("summer", day_type)
            base_profile = [0.60, 0.55, 0.50, 0.50, 0.55, 0.65, 0.80, 0.95, 1.00, 0.95, 
                           0.95, 1.00, 1.00, 1.00, 0.95, 0.95, 1.00, 1.00, 0.95, 0.90, 
                           0.85, 0.80, 0.70, 0.65]
        else
            base_profile = [0.60, 0.55, 0.55, 0.50, 0.55, 0.65, 0.80, 0.95, 1.00, 0.95, 
                           0.90, 0.90, 0.85, 0.85, 0.90, 0.95, 1.00, 0.95, 0.90, 0.85, 
                           0.80, 0.75, 0.70, 0.65]
        end
    else  # thermal
        base_profile = fill(0.6, hours)
    end
    
    # Add stochastic variation
    return [max(0.1, x * (1 + 0.1 * randn())) for x in base_profile]
end

function generate_renewable_profile(resource_type::String, day_type::String)
    hours = 24
    if resource_type == "solar"
        # Solar profile with seasonal variation
        base_profile = [0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.3, 0.5, 0.7, 0.8, 
                       0.9, 1.0, 1.0, 0.9, 0.8, 0.6, 0.4, 0.2, 0.0, 0.0, 
                       0.0, 0.0, 0.0, 0.0]
        
        # Seasonal adjustment
        if occursin("winter", day_type)
            base_profile = base_profile .* 0.6
        elseif occursin("summer", day_type)
            base_profile = base_profile .* 1.2
        end
    else  # wind
        base_profile = fill(0.5, hours)
    end
    
    # Add weather uncertainty
    return [max(0.0, x * (1 + 0.3 * randn())) for x in base_profile]
end

function get_seasonal_factor(day_type::String, parent_data::Dict{Symbol, Any})
    # Seasonal adjustment based on parent year conditions
    base_factor = 1.0
    
    if haskey(parent_data, :demand_growth)
        base_factor *= parent_data[:demand_growth]
    end
    
    if occursin("winter", day_type)
        return base_factor * 1.1  # Higher winter demand
    elseif occursin("summer", day_type)
        return base_factor * 1.05  # Slightly higher summer demand
    else
        return base_factor
    end
end

# ========== Layer Mapping System ==========

"""
    LayerConfig

Configuration structure for defining layer mappings and properties.
"""
struct LayerConfig
    layer_id::Int                           # Internal layer ID (1, 2, 3, ...)
    layer_name::Symbol                      # User-defined layer name
    layer_description::String               # Human-readable description
    time_structure_key::Symbol              # Key in time_structure dict
    branching_factor_key::Symbol            # Key in branching_factors dict
    data_extraction_method::Symbol          # Method for extracting layer-specific data
end

"""
    create_layer_mapping(layer_definitions::Vector)

Create a standardized layer mapping from user-defined layer specifications.

Parameters:
- layer_definitions: Vector of tuples (layer_name, description, time_key, branching_key, data_method)

Returns:
- Dict mapping layer_name to LayerConfig
"""
function create_layer_mapping(layer_definitions::Vector)
    layer_mapping = Dict{Symbol, LayerConfig}()
    
    for (i, layer_def) in enumerate(layer_definitions)
        # Handle different tuple types
        if length(layer_def) >= 5
            layer_name, description, time_key, branching_key, data_method = layer_def[1:5]
        else
            error("Layer definition must have at least 5 elements: (layer_name, description, time_key, branching_key, data_method)")
        end
        
        layer_config = LayerConfig(
            i,                      # layer_id
            Symbol(layer_name),     # layer_name
            String(description),    # layer_description
            Symbol(time_key),       # time_structure_key
            Symbol(branching_key),  # branching_factor_key
            Symbol(data_method)     # data_extraction_method
        )
        layer_mapping[Symbol(layer_name)] = layer_config
    end
    
    return layer_mapping
end

"""
    get_default_three_layer_mapping()

Get the default three-layer configuration for backward compatibility.
"""
function get_default_three_layer_mapping()
    layer_definitions = [
        ("year", "Strategic planning horizon", "years", "year", "extract_year_data"),
        ("week", "Weekly operational patterns", "weeks_per_year", "week", "extract_week_data"),
        ("day", "Daily operational cycles", "days_per_week", "day", "extract_day_data")
    ]
    return create_layer_mapping(layer_definitions)
end

"""
    get_default_five_layer_mapping()

Get a five-layer configuration example.
"""
function get_default_five_layer_mapping()
    layer_definitions = [
        ("year", "Strategic planning horizon", "years", "year", "extract_year_data"),
        ("month", "Monthly seasonal patterns", "months_per_year", "month", "extract_month_data"),
        ("week", "Weekly operational patterns", "weeks_per_month", "week", "extract_week_data"),
        ("day", "Daily operational cycles", "days_per_week", "day", "extract_day_data"),
        ("hour", "Hourly dispatch decisions", "hours_per_day", "hour", "extract_hour_data")
    ]
    return create_layer_mapping(layer_definitions)
end

# ========== Tree Construction ==========

function create_scenario_node(time_scale::Symbol, time_index::Int, parent::Union{ScenarioNode, Nothing}, 
                             data::Dict{Symbol, Any}, conditional_prob::Float64)
    ScenarioNode(
        generate_unique_id(),
        time_scale,
        time_index,
        parent,
        ScenarioNode[],
        0.0,  # Will be computed during normalization
        conditional_prob,
        data
    )
end

function build_nested_scenario_tree(time_structure::Dict{Symbol, Int}, base_parameters::Dict{Symbol, Any}, 
                                   branching_factors::Dict{Symbol, Int}, layers::Vector{Symbol};
                                   layer_mapping::Union{Dict{Symbol, LayerConfig}, Nothing} = nothing)
    reset_id_counter()
    root_nodes = ScenarioNode[]
    
    # Create layer mapping if not provided
    if layer_mapping === nothing
        if length(layers) == 3
            layer_mapping = get_default_three_layer_mapping()
        elseif length(layers) == 5
            layer_mapping = get_default_five_layer_mapping()
        else
            # Create generic mapping for custom layer counts
            layer_definitions = []
            for (i, layer_name) in enumerate(layers)
                push!(layer_definitions, (
                    string(layer_name),           # layer_name
                    "Layer $i: $layer_name",     # description
                    layer_name,                   # time_structure_key
                    layer_name,                   # branching_factor_key
                    Symbol("extract_$(layer_name)_data")  # data_extraction_method
                ))
            end
            layer_mapping = create_layer_mapping(layer_definitions)
        end
    end
    
    # Validate layer mapping
    validate_layer_mapping(layer_mapping, layers, time_structure, branching_factors)
    
    # Handle different parameter structures
    scenario_data = base_parameters
    
    # Check if we have the expected layer data structure
    if all(haskey(base_parameters, layer) for layer in layers)
        scenario_data = base_parameters
    elseif haskey(base_parameters, :parameters)
        scenario_data = merge(base_parameters, base_parameters[:parameters])
    end
    
    # Create root nodes based on first layer
    first_layer = layers[1]
    first_layer_config = layer_mapping[first_layer]
    
    n_items = get(time_structure, first_layer_config.time_structure_key, 1)
    for i in 1:n_items
        node_data = extract_layer_data_generic(scenario_data, first_layer, i, nothing, layer_mapping)
        conditional_prob = 1.0 / n_items
        root_node = create_scenario_node(first_layer, i, nothing, node_data, conditional_prob)
        push!(root_nodes, root_node)
        
        # Generate children recursively
        if length(layers) > 1
            generate_children_generic!(root_node, 2, layers, time_structure, branching_factors, scenario_data, layer_mapping)
        end
    end
    
    # Create tree structure
    total_nodes, total_paths = count_tree_stats(root_nodes, layers)
    tree = NestedScenarioTreeType(root_nodes, layers, time_structure, total_nodes, total_paths, time())
    
    # Normalize probabilities
    normalize_tree_probabilities!(tree)
    
    return tree
end

"""
    validate_layer_mapping(layer_mapping, layers, time_structure, branching_factors)

Validate that the layer mapping is consistent with provided parameters.
"""
function validate_layer_mapping(layer_mapping::Dict{Symbol, LayerConfig}, 
                               layers::Vector{Symbol}, 
                               time_structure::Dict{Symbol, Int}, 
                               branching_factors::Dict{Symbol, Int})
    
    for layer in layers
        if !haskey(layer_mapping, layer)
            error("Layer mapping missing for layer: $layer")
        end
        
        config = layer_mapping[layer]
        
        # Check time structure key exists
        if !haskey(time_structure, config.time_structure_key)
            @warn "Time structure missing key: $(config.time_structure_key) for layer: $layer"
        end
        
        # Check branching factor key exists
        if !haskey(branching_factors, config.branching_factor_key)
            @warn "Branching factors missing key: $(config.branching_factor_key) for layer: $layer"
        end
    end
end

"""
    extract_layer_data_generic(scenario_data, layer, index, parent, layer_mapping)

Generic layer data extraction using configurable mapping.
"""
function extract_layer_data_generic(scenario_data::Dict{Symbol, Any}, layer::Symbol, index::Int, 
                                   parent::Union{ScenarioNode, Nothing}, 
                                   layer_mapping::Dict{Symbol, LayerConfig})
    data = Dict{Symbol, Any}()
    
    if !haskey(layer_mapping, layer)
        error("Unknown layer: $layer")
    end
    
    config = layer_mapping[layer]
    extraction_method = config.data_extraction_method
    
    # Call the appropriate extraction method based on configuration
    if extraction_method == :extract_year_data
        return extract_year_data(scenario_data, index, parent)
    elseif extraction_method == :extract_month_data
        return extract_month_data(scenario_data, index, parent)
    elseif extraction_method == :extract_week_data
        return extract_week_data(scenario_data, index, parent)
    elseif extraction_method == :extract_day_data
        return extract_day_data(scenario_data, index, parent)
    elseif extraction_method == :extract_hour_data
        return extract_hour_data(scenario_data, index, parent)
    else
        # Generic fallback extraction
        return extract_generic_layer_data(scenario_data, layer, index, parent, config)
    end
end

"""
    generate_children_generic!(parent_node, layer_idx, layers, time_structure, branching_factors, scenario_data, layer_mapping)

Generate children nodes using generic layer mapping.
"""
function generate_children_generic!(parent_node::ScenarioNode, layer_idx::Int, layers::Vector{Symbol}, 
                                   time_structure::Dict{Symbol, Int}, branching_factors::Dict{Symbol, Int}, 
                                   scenario_data::Dict{Symbol, Any}, layer_mapping::Dict{Symbol, LayerConfig})
    if layer_idx > length(layers)
        return
    end
    
    current_layer = layers[layer_idx]
    current_config = layer_mapping[current_layer]
    
    # Get number of children from branching factors using the mapped key
    num_children = get(branching_factors, current_config.branching_factor_key, 1)
    
    for i in 1:num_children
        child_data = extract_layer_data_generic(scenario_data, current_layer, i, parent_node, layer_mapping)
        conditional_prob = 1.0 / num_children  # Simplified probability
        child_node = create_scenario_node(current_layer, i, parent_node, child_data, conditional_prob)
        push!(parent_node.children, child_node)
        
        # Recursive generation for next layer
        if layer_idx < length(layers)
            generate_children_generic!(child_node, layer_idx + 1, layers, time_structure, branching_factors, scenario_data, layer_mapping)
        end
    end
end

# ========== Specific Data Extraction Methods ==========

function extract_year_data(scenario_data::Dict{Symbol, Any}, index::Int, parent::Union{ScenarioNode, Nothing})
    data = Dict{Symbol, Any}()
    
    if haskey(scenario_data, :year) && haskey(scenario_data[:year], index)
        year_data = scenario_data[:year][index]
        for (key, value) in year_data
            data[key] = value
        end
    else
        # Generate default year data
        data[:demand_growth] = 1.02^(index-1)
        data[:carbon_budget] = get(scenario_data, :carbon_budgets, [5000.0, 4750.0, 4500.0])[min(index, 3)]
        data[:carbon_price] = get(scenario_data, :carbon_prices, [50.0, 52.5, 55.0])[min(index, 3)]
        data[:year_index] = index
    end
    
    return data
end

function extract_month_data(scenario_data::Dict{Symbol, Any}, index::Int, parent::Union{ScenarioNode, Nothing})
    data = Dict{Symbol, Any}()
    
    if haskey(scenario_data, :month) && haskey(scenario_data[:month], index)
        month_data = scenario_data[:month][index]
        for (key, value) in month_data
            data[key] = value
        end
    else
        # Generate default month data
        data[:seasonal_factor] = 1.0 + 0.3*sin(2π*(index-1)/12)
        data[:heating_cooling_demand] = index in [12,1,2,6,7,8] ? 1.3 : 1.0
        data[:month_index] = index
    end
    
    return data
end

function extract_week_data(scenario_data::Dict{Symbol, Any}, index::Int, parent::Union{ScenarioNode, Nothing})
    data = Dict{Symbol, Any}()
    
    if haskey(scenario_data, :week) && haskey(scenario_data[:week], index)
        week_data = scenario_data[:week][index]
        for (key, value) in week_data
            data[key] = value
        end
    else
        # Generate default week data
        weekly_factors = get(scenario_data, :weekly_demand_factors, [1.0, 1.1, 1.2, 0.9])
        renewable_factors = get(scenario_data, :weekly_renewable_factors, Dict(:solar => [1.0, 1.2, 1.5, 1.0], :wind => [1.3, 1.1, 0.7, 1.0]))
        
        data[:weekly_demand_factor] = weekly_factors[min(index, length(weekly_factors))]
        data[:solar_factor] = renewable_factors[:solar][min(index, length(renewable_factors[:solar]))]
        data[:wind_factor] = renewable_factors[:wind][min(index, length(renewable_factors[:wind]))]
        data[:week_index] = index
    end
    
    return data
end

function extract_day_data(scenario_data::Dict{Symbol, Any}, index::Int, parent::Union{ScenarioNode, Nothing})
    data = Dict{Symbol, Any}()
    
    if haskey(scenario_data, :day) && haskey(scenario_data[:day], index)
        day_data = scenario_data[:day][index]
        for (key, value) in day_data
            data[key] = value
        end
    else
        # Generate default day data
        daily_patterns = get(scenario_data, :daily_patterns, [1.2, 1.1, 1.1, 1.1, 1.0, 0.8, 0.7])
        
        data[:day_type] = index <= 5 ? "weekday" : "weekend"
        data[:daily_factor] = daily_patterns[min(index, length(daily_patterns))]
        data[:day_index] = index
        
        # Add hourly averages
        data[:electricity_load_avg] = 0.8 + 0.2*sin(2π*(index-1)/7)
        data[:thermal_load_avg] = 0.6 + 0.1*sin(2π*(index-1)/7)
        data[:solar_output_avg] = 0.3 + 0.2*rand()
        data[:wind_output_avg] = 0.5 + 0.3*rand()
    end
    
    return data
end

function extract_hour_data(scenario_data::Dict{Symbol, Any}, index::Int, parent::Union{ScenarioNode, Nothing})
    data = Dict{Symbol, Any}()
    
    if parent !== nothing && haskey(parent.data, :electricity_load_avg)
        # Extract hourly values from parent day patterns
        base_load = parent.data[:electricity_load_avg]
        hourly_pattern = 0.8 + 0.4*sin(2π*(index-6)/24)  # Daily pattern
        
        data[:hour_index] = index
        data[:electricity_load] = base_load * hourly_pattern * (1 + 0.05 * randn())
        data[:thermal_load] = get(parent.data, :thermal_load_avg, 0.6) * hourly_pattern * (1 + 0.05 * randn())
        data[:solar_output] = max(0, sin(π*(index-6)/12)) * get(parent.data, :solar_output_avg, 0.3)
        data[:wind_output] = get(parent.data, :wind_output_avg, 0.5) * (1 + 0.1 * randn())
    else
        # Default hourly values
        data[:hour_index] = index
        data[:electricity_load] = 0.8 + 0.4*sin(2π*(index-6)/24)
        data[:thermal_load] = 0.6 + 0.2*sin(2π*(index-6)/24)
        data[:solar_output] = max(0, sin(π*(index-6)/12))
        data[:wind_output] = 0.5 + 0.3*rand()
    end
    
    return data
end

"""
    extract_generic_layer_data(scenario_data, layer, index, parent, config)

Generic fallback data extraction for custom layers.
"""
function extract_generic_layer_data(scenario_data::Dict{Symbol, Any}, layer::Symbol, index::Int, 
                                   parent::Union{ScenarioNode, Nothing}, config::LayerConfig)
    data = Dict{Symbol, Any}()
    
    # Try to extract from scenario_data using layer name
    if haskey(scenario_data, layer) && haskey(scenario_data[layer], index)
        layer_data = scenario_data[layer][index]
        for (key, value) in layer_data
            data[key] = value
        end
    else
        # Create minimal default data
        data[Symbol("$(layer)_index")] = index
        data[Symbol("$(layer)_factor")] = 1.0 + 0.1 * randn()
        data[:layer] = layer
        data[:layer_id] = config.layer_id
    end
    
    return data
end

# ========== Tree Statistics ==========

function count_tree_stats(root_nodes::Vector{ScenarioNode}, layers::Vector{Symbol})
    total_nodes = 0
    total_paths = 0
    
    function count_nodes(node::ScenarioNode)
        total_nodes += 1
        if isempty(node.children)
            total_paths += 1
        else
            for child in node.children
                count_nodes(child)
            end
        end
    end
    
    for root in root_nodes
        count_nodes(root)
    end
    
    return total_nodes, total_paths
end

# ========== Path Generation ==========

function generate_scenario_paths(tree::NestedScenarioTreeType)
    paths = ScenarioPath[]
    path_counter = Ref(0)
    
    for root in tree.root_nodes
        traverse_paths!(root, ScenarioNode[], paths, path_counter)
    end
    
    return paths
end

function traverse_paths!(node::ScenarioNode, current_path::Vector{ScenarioNode}, 
                        paths::Vector{ScenarioPath}, path_counter::Ref{Int})
    push!(current_path, node)
    
    if isempty(node.children)
        # Leaf node - create complete path
        path_counter[] += 1
        path_probability = node.probability
        push!(paths, ScenarioPath(copy(current_path), path_probability, path_counter[]))
    else
        # Internal node - continue traversal
        for child in node.children
            traverse_paths!(child, current_path, paths, path_counter)
        end
    end
    
    pop!(current_path)
end

# ========== Updated Tree Validation ==========

function validate_tree_quality(tree::NestedScenarioTreeType)
    validation_results = Dict{String, Any}()
    
    # 1. Probability validation
    paths = generate_scenario_paths(tree)
    total_prob = sum([path.probability for path in paths])
    validation_results["probability_sum"] = total_prob
    validation_results["probability_error"] = abs(total_prob - 1.0)
    validation_results["probability_valid"] = abs(total_prob - 1.0) < 1e-6
    
    # 2. Tree structure validation using generic layer mapping
    validation_results["total_paths"] = length(paths)
    
    # Calculate expected paths by multiplying branching factors for each layer
    expected_paths = 1
    for layer in tree.layers
        # Use a more generic approach to find layer size
        layer_size = get_layer_size_generic(tree.time_structure, layer)
        expected_paths *= layer_size
    end
    
    validation_results["expected_paths"] = expected_paths
    validation_results["structure_valid"] = validation_results["total_paths"] == validation_results["expected_paths"]
    
    # 3. Data consistency validation
    data_consistent = true
    for path in paths[1:min(10, length(paths))]  # Sample check
        for i in 2:length(path.nodes)
            parent_node = path.nodes[i-1]
            child_node = path.nodes[i]
            if child_node.parent !== parent_node
                data_consistent = false
                break
            end
        end
        if !data_consistent
            break
        end
    end
    validation_results["data_consistent"] = data_consistent
    
    return validation_results
end

"""
    get_layer_size_generic(time_structure, layer)

Generic function to get layer size from time structure.
"""
function get_layer_size_generic(time_structure::Dict{Symbol, Int}, layer::Symbol)
    # Common mappings
    layer_size_mappings = Dict(
        :year => [:years],
        :month => [:months_per_year, :months],
        :week => [:weeks_per_year, :weeks_per_month, :weeks],
        :day => [:days_per_week, :days_per_month, :days],
        :hour => [:hours_per_day, :hours]
    )
    
    # Try direct lookup first
    if haskey(time_structure, layer)
        return time_structure[layer]
    end
    
    # Try common mappings
    if haskey(layer_size_mappings, layer)
        for key in layer_size_mappings[layer]
            if haskey(time_structure, key)
                return time_structure[key]
            end
        end
    end
    
    # Default fallback
    return 1
end

# ========== Example Function ==========

function example_lifecycle_tree()
    # Include the life cycle scenarios module with correct path
    include("life_cycle_scenarios.jl")
    base = generate_lifecycle_scenarios(years=2, typical_days=2, hours_per_day=3)
    
    # Convert to symbol keys
    converted_base = Dict{Symbol, Any}()
    for (key, value) in base
        converted_base[Symbol(key)] = value
    end
    
    # Define tree structure
    layers = [:year, :typical_day, :hour]
    time_structure = Dict(:years => 2, :typical_days => 2, :hours_per_day => 3)
    branching_factors = Dict(:year => 2, :typical_day => 2, :hour => 3)
    
    # Build tree
    tree = build_nested_scenario_tree(time_structure, converted_base, branching_factors, layers)
    
    # Generate and validate paths
    paths = generate_scenario_paths(tree)
    validation = validate_tree_quality(tree)
    
    println("Tree built: $(tree.total_nodes) nodes, $(tree.total_paths) scenario paths.")
    println("Probability sum: $(validation["probability_sum"])")
    println("Structure valid: $(validation["structure_valid"])")
    
    # Display sample paths
    for (i, path) in enumerate(paths[1:min(3, length(paths))])
        println("Path $i: ", [(n.time_scale, n.time_index) for n in path.nodes], " | Prob: ", round(path.probability, digits=6))
    end
    
    return tree, paths, validation
end

end
