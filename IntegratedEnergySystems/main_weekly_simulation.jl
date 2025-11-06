 # Main script to run the low-carbon energy system model

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

# function run_energy_system_model()
    println("Running low-carbon energy system model...")
    
    # Create sample parameters
    params = create_weekly_sample_parameters()
    
    # Extract time steps
    T = params["T"]
    
    # Create the model
    model = create_low_carbon_energy_system_model(params)
    
    # Solve the model
    results = solve_model(model)
    
    # Extract and analyze results
    results = extract_results(model)
    
    # if results !== nothing
        # Analyze results
        metrics = analyze_results(results, T, params)
        
        # Check energy balance
        balance_ok = check_energy_balance(results, T, params)
        
        # Analyze system efficiency
        efficiency_metrics = analyze_system_efficiency(results, T, params)
        
        # Visualize results
        visualize_all_results(results, T, params)
        
    #     return results, metrics, efficiency_metrics
    # else
    #     println("Failed to solve the model.")
    #     return nothing
    # end
    
    # return results, metrics, efficiency_metrics
# end

# Run the model if this script is executed directly
# if abspath(PROGRAM_FILE) == @__FILE__
# results, metrics, efficiency_metrics = run_energy_system_model()
# # end
# @show efficiency_metrics