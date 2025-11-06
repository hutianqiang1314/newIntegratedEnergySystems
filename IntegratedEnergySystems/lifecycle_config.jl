# lifecycle_config.jl
# Configuration module for lifecycle simulation parameters

"""
    LifeCycleConfig

Configuration module for lifecycle simulation parameters and settings.
"""
module LifeCycleConfig

export get_simulation_config, get_stochastic_strategies, validate_config

"""
    get_simulation_config()

Get default simulation configuration parameters.
"""
function get_simulation_config()
    return Dict(
        "years" => 3,
        "weeks_per_year" => 4,
        "days_per_week" => 7,
        "hours_per_day" => 24,
        "output_dirs" => Dict(
            "export" => "scenario_tree_export",
            "results" => "nested_tree_results", 
            "lifecycle" => "lifecycle_results",
            "sensitivity" => "sensitivity_results",
            "stochastic" => "stochastic_analysis_results",
            "strategy" => "strategy_comparison",
            "documentation" => "comprehensive_documentation"
        ),
        "monte_carlo_samples" => 200
    )
end

"""
    get_stochastic_strategies()

Get predefined stochastic strategy configurations.
"""
function get_stochastic_strategies()
    return Dict(
        "conservative" => Dict("cost_factor" => 1.1, "uncertainty_factor" => 0.05),
        "aggressive" => Dict("cost_factor" => 0.9, "uncertainty_factor" => 0.15),
        "balanced" => Dict("cost_factor" => 1.0, "uncertainty_factor" => 0.10)
    )
end

"""
    validate_config(config::Dict)

Validate simulation configuration parameters.
"""
function validate_config(config::Dict)
    required_keys = ["years", "weeks_per_year", "days_per_week", "hours_per_day"]
    
    for key in required_keys
        if !haskey(config, key)
            error("Missing required configuration key: $key")
        end
        if config[key] <= 0
            error("Configuration parameter $key must be positive")
        end
    end
    
    return true
end

end # module
