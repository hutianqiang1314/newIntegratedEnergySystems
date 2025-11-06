# stochastic_analysis_manager.jl
# Manager for stochastic analysis components

"""
    StochasticAnalysisManager

Manager module for stochastic analysis components and strategies.
"""
module StochasticAnalysisManager

using ..LifeCycleConfig
export check_stochastic_availability, run_stochastic_analysis, run_strategy_comparison

# Global flag for stochastic analysis availability
STOCHASTIC_ANALYSIS_AVAILABLE = false

"""
    check_stochastic_availability()

Check if stochastic analysis module is available and initialize it.
"""
function check_stochastic_availability()
    global STOCHASTIC_ANALYSIS_AVAILABLE
    
    try
        # Try to include the stochastic analysis module
        Base.include(@__MODULE__, "stochastic_analysis.jl")
        # Set flag to true if successful
        STOCHASTIC_ANALYSIS_AVAILABLE = true
        println("StochasticAnalysis module loaded successfully")
        return true
    catch e
        println("Warning: StochasticAnalysis module not available: $e")
        STOCHASTIC_ANALYSIS_AVAILABLE = false
        return false
    end
end

"""
    run_stochastic_analysis(tree, base_scenarios, config::Dict)

Run stochastic analysis if available.
"""
function run_stochastic_analysis(tree, base_scenarios, config::Dict)
    stochastic_results = Dict()
    
    if !STOCHASTIC_ANALYSIS_AVAILABLE
        check_stochastic_availability()
    end
    
    if STOCHASTIC_ANALYSIS_AVAILABLE && tree !== nothing
        try
            # Access StochasticAnalysis through Main module
            samples = get(config, "monte_carlo_samples", 200)
            
            # Try to call the stochastic analysis function
            if isdefined(Main, :StochasticAnalysis)
                stochastic_results = Main.StochasticAnalysis.run_comprehensive_stochastic_analysis(tree, base_scenarios, samples)
                println("Stochastic analysis completed successfully")
            else
                println("Warning: StochasticAnalysis module not properly loaded")
            end
        catch e
            println("Warning: Stochastic analysis execution failed: $e")
        end
    else
        println("Stochastic analysis module not available or tree invalid, skipping...")
    end
    
    return stochastic_results
end

"""
    run_strategy_comparison(tree, base_scenarios, config::Dict)

Run strategy comparison if stochastic analysis is available.
"""
function run_strategy_comparison(tree, base_scenarios, config::Dict)
    strategy_comparison = Dict()
    
    if STOCHASTIC_ANALYSIS_AVAILABLE && tree !== nothing
        try
            strategies = get_stochastic_strategies()
            
            # Try to call the strategy comparison function
            if isdefined(Main, :StochasticAnalysis)
                strategy_comparison = Main.StochasticAnalysis.compare_stochastic_strategies(strategies, tree, base_scenarios)
                println("Strategy comparison completed successfully")
            else
                println("Warning: StochasticAnalysis module not properly loaded for strategy comparison")
            end
        catch e
            println("Warning: Strategy comparison failed: $e")
        end
    else
        println("Strategy comparison requires StochasticAnalysis module and valid tree, skipping...")
    end
    
    return strategy_comparison
end

end # module
