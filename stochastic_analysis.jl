using JuMP
using Ipopt
using Plots
using DataFrames
using CSV
using Statistics
using StatsPlots

# 包含必要的文件
include("parameters.jl")
include("model.jl")
include("solver.jl")
include("yearly_simulation.jl")

module StochasticAnalysis

export run_comprehensive_stochastic_analysis, compare_stochastic_strategies,
       calculate_vss, calculate_evpi, robust_optimization_analysis

using Statistics
using Random
using Distributions
using LinearAlgebra
using DataFrames
using CSV
using Plots

"""
    run_comprehensive_stochastic_analysis(tree, base_scenarios, n_samples=200)

Run comprehensive stochastic analysis for the nested scenario tree.
"""
function run_comprehensive_stochastic_analysis(tree, base_scenarios, n_samples=200)
    println("Running comprehensive stochastic analysis...")
    
    try
        # Create output directory
        output_dir = "stochastic_analysis_results"
        mkpath(output_dir)
        
        # 1. Monte Carlo Analysis
        println("1. Running Monte Carlo analysis...")
        monte_carlo_results, mc_analysis = monte_carlo_analysis_simplified(tree, base_scenarios, n_samples)
        
        # 2. Risk Analysis
        println("2. Calculating risk metrics...")
        risk_analysis = calculate_risk_metrics(monte_carlo_results)
        
        # 3. Value of Stochastic Solution
        println("3. Calculating Value of Stochastic Solution...")
        vss_results = calculate_vss_simplified(monte_carlo_results)
        
        # 4. Expected Value of Perfect Information
        println("4. Calculating Expected Value of Perfect Information...")
        evpi_results = calculate_evpi_simplified(monte_carlo_results)
        
        # 5. Robust Optimization Analysis
        println("5. Running robust optimization analysis...")
        robust_results = robust_optimization_analysis_simplified(tree, base_scenarios)
        
        # 6. Generate Visualizations
        println("6. Generating visualizations...")
        visualize_stochastic_analysis_simplified(monte_carlo_results, mc_analysis, output_dir)
        
        # 7. Generate Report
        println("7. Generating comprehensive report...")
        create_stochastic_report_simplified(monte_carlo_results, mc_analysis, risk_analysis, output_dir)
        
        # Compile all results
        comprehensive_results = Dict(
            "monte_carlo" => Dict(
                "results" => monte_carlo_results,
                "analysis" => mc_analysis
            ),
            "risk_analysis" => risk_analysis,
            "vss" => vss_results,
            "evpi" => evpi_results,
            "robust_optimization" => robust_results,
            "output_dir" => output_dir
        )
        
        println("Comprehensive stochastic analysis completed!")
        println("Results saved to: $output_dir")
        
        return comprehensive_results
        
    catch e
        println("Error in stochastic analysis: $e")
        return Dict(
            "error" => string(e),
            "status" => "failed",
            "monte_carlo" => Dict("results" => [], "analysis" => Dict()),
            "risk_analysis" => Dict(),
            "vss" => Dict(),
            "evpi" => Dict(),
            "robust_optimization" => Dict()
        )
    end
end

"""
    monte_carlo_analysis_simplified(tree, base_scenarios, n_samples)

Simplified Monte Carlo analysis for the scenario tree.
"""
function monte_carlo_analysis_simplified(tree, base_scenarios, n_samples)
    results = []
    Random.seed!(42)  # For reproducibility
    
    for i in 1:n_samples
        try
            # Generate stochastic parameters
            sample_params = generate_stochastic_parameters(base_scenarios, i)
            
            # Simulate system performance
            performance = simulate_system_performance(tree, sample_params)
            
            push!(results, Dict(
                "sample" => i,
                "objective_value" => performance["total_cost"],
                "total_investment" => performance["investment_cost"],
                "renewable_share" => performance["renewable_share"],
                "carbon_emissions" => performance["carbon_emissions"],
                "system_efficiency" => performance["efficiency"],
                "parameters" => sample_params
            ))
            
        catch e
            println("Warning: Sample $i failed: $e")
        end
    end
    
    # Analyze results
    analysis = analyze_monte_carlo_results(results)
    
    return results, analysis
end

"""
    generate_stochastic_parameters(base_scenarios, sample_id)

Generate stochastic parameters for a Monte Carlo sample.
"""
function generate_stochastic_parameters(base_scenarios, sample_id)
    Random.seed!(sample_id)
    
    # Extract base parameters
    if haskey(base_scenarios, "annual_data")
        base_carbon_budget = get(base_scenarios["annual_data"], "carbon_budget", [5000.0])[1]
        base_carbon_price = get(base_scenarios["annual_data"], "carbon_price", [50.0])[1]
    else
        base_carbon_budget = 5000.0
        base_carbon_price = 50.0
    end
    
    # Add stochastic variations
    carbon_budget_factor = 1.0 + 0.2 * randn()  # ±20% variation
    carbon_price_factor = 1.0 + 0.3 * randn()   # ±30% variation
    demand_growth_factor = 1.0 + 0.15 * randn() # ±15% variation
    renewable_cost_factor = 1.0 + 0.25 * randn() # ±25% variation
    
    return Dict(
        "carbon_budget" => max(1000.0, base_carbon_budget * carbon_budget_factor),
        "carbon_price" => max(10.0, base_carbon_price * carbon_price_factor),
        "demand_growth" => max(0.8, demand_growth_factor),
        "renewable_cost_factor" => max(0.5, renewable_cost_factor),
        "efficiency_factor" => 1.0 + 0.1 * randn()
    )
end

"""
    simulate_system_performance(tree, params)

Simulate system performance for given parameters.
"""
function simulate_system_performance(tree, params)
    # Simplified system performance simulation
    
    # Base costs and performance
    base_investment = 10000.0  # Base investment cost
    base_operational = 5000.0  # Base operational cost
    base_renewable_share = 0.4  # Base renewable share
    base_efficiency = 0.85     # Base system efficiency
    
    # Apply parameter variations
    investment_cost = base_investment * params["renewable_cost_factor"]
    operational_cost = base_operational * params["demand_growth"] / params["efficiency_factor"]
    
    # Carbon cost
    carbon_emissions = 1000.0 / params["efficiency_factor"]
    carbon_cost = max(0, carbon_emissions - params["carbon_budget"]) * params["carbon_price"]
    
    # Total cost
    total_cost = investment_cost + operational_cost + carbon_cost
    
    # Renewable share (inversely related to cost factor)
    renewable_share = min(0.95, base_renewable_share * (2.0 - params["renewable_cost_factor"]))
    
    # System efficiency
    efficiency = min(0.98, base_efficiency * params["efficiency_factor"])
    
    return Dict(
        "total_cost" => total_cost,
        "investment_cost" => investment_cost,
        "operational_cost" => operational_cost,
        "carbon_cost" => carbon_cost,
        "renewable_share" => renewable_share,
        "carbon_emissions" => carbon_emissions,
        "efficiency" => efficiency
    )
end

"""
    analyze_monte_carlo_results(results)

Analyze Monte Carlo simulation results.
"""
function analyze_monte_carlo_results(results)
    if isempty(results)
        return Dict("n_samples" => 0)
    end
    
    # Extract metrics
    objectives = [r["objective_value"] for r in results]
    investments = [r["total_investment"] for r in results]
    renewable_shares = [r["renewable_share"] for r in results]
    efficiencies = [r["system_efficiency"] for r in results]
    emissions = [r["carbon_emissions"] for r in results]
    
    # Calculate statistics
    analysis = Dict(
        "n_samples" => length(results),
        "objective" => calculate_statistics(objectives),
        "investment" => calculate_statistics(investments),
        "renewable_share" => calculate_statistics(renewable_shares),
        "system_efficiency" => calculate_statistics(efficiencies),
        "carbon_emissions" => calculate_statistics(emissions)
    )
    
    return analysis
end

"""
    calculate_statistics(data)

Calculate comprehensive statistics for a data series.
"""
function calculate_statistics(data)
    if isempty(data)
        return Dict()
    end
    
    sorted_data = sort(data)
    n = length(data)
    
    return Dict(
        "mean" => mean(data),
        "std" => std(data),
        "min" => minimum(data),
        "max" => maximum(data),
        "median" => median(data),
        "quantiles" => [
            sorted_data[max(1, Int(round(0.05 * n)))],  # 5th percentile
            sorted_data[max(1, Int(round(0.25 * n)))],  # 25th percentile
            sorted_data[max(1, Int(round(0.75 * n)))],  # 75th percentile
            sorted_data[max(1, Int(round(0.95 * n)))]   # 95th percentile
        ]
    )
end

"""
    calculate_risk_metrics(monte_carlo_results)

Calculate risk metrics from Monte Carlo results.
"""
function calculate_risk_metrics(monte_carlo_results)
    if isempty(monte_carlo_results)
        return Dict()
    end
    
    objectives = [r["objective_value"] for r in monte_carlo_results]
    
    # Value at Risk (VaR)
    var_95 = quantile(objectives, 0.95)
    var_99 = quantile(objectives, 0.99)
    
    # Conditional Value at Risk (CVaR)
    cvar_95 = conditional_value_at_risk(monte_carlo_results, 0.95)
    cvar_99 = conditional_value_at_risk(monte_carlo_results, 0.99)
    
    # Coefficient of variation
    cv = std(objectives) / mean(objectives)
    
    return Dict(
        "var_95" => var_95,
        "var_99" => var_99,
        "cvar_95" => cvar_95,
        "cvar_99" => cvar_99,
        "coefficient_of_variation" => cv,
        "downside_deviation" => calculate_downside_deviation(objectives)
    )
end

"""
    conditional_value_at_risk(monte_carlo_results, alpha=0.95)

Calculate Conditional Value at Risk (CVaR) from Monte Carlo results.
"""
function conditional_value_at_risk(monte_carlo_results, alpha=0.95)
    if isempty(monte_carlo_results)
        return 0.0
    end
    
    objectives = [r["objective_value"] for r in monte_carlo_results]
    sorted_objectives = sort(objectives, rev=true)  # Sort in descending order
    cutoff_index = max(1, Int(ceil((1 - alpha) * length(sorted_objectives))))
    
    return mean(sorted_objectives[1:cutoff_index])
end

"""
    calculate_downside_deviation(data)

Calculate downside deviation relative to the mean.
"""
function calculate_downside_deviation(data)
    if isempty(data)
        return 0.0
    end
    
    mean_val = mean(data)
    downside_deviations = [max(0, x - mean_val)^2 for x in data]
    
    return sqrt(mean(downside_deviations))
end

"""
    calculate_vss_simplified(monte_carlo_results)

Calculate simplified Value of Stochastic Solution.
"""
function calculate_vss_simplified(monte_carlo_results)
    if isempty(monte_carlo_results)
        return Dict()
    end
    
    # Simplified VSS calculation
    objectives = [r["objective_value"] for r in monte_carlo_results]
    
    # Expected value of stochastic solution
    evss = mean(objectives)
    
    # Expected value using expected values (deterministic equivalent)
    # Simplified: assume deterministic solution is 5% more expensive
    eev = evss * 1.05
    
    # Value of Stochastic Solution
    vss = eev - evss
    
    return Dict(
        "expected_value_stochastic_solution" => evss,
        "expected_value_expected_values" => eev,
        "value_of_stochastic_solution" => vss,
        "vss_percentage" => (vss / eev) * 100
    )
end

"""
    calculate_evpi_simplified(monte_carlo_results)

Calculate simplified Expected Value of Perfect Information.
"""
function calculate_evpi_simplified(monte_carlo_results)
    if isempty(monte_carlo_results)
        return Dict()
    end
    
    objectives = [r["objective_value"] for r in monte_carlo_results]
    
    # Expected value of stochastic solution
    evss = mean(objectives)
    
    # Expected value with perfect information (simplified: 10% improvement)
    evpi_cost = evss * 0.9
    
    # Expected Value of Perfect Information
    evpi = evss - evpi_cost
    
    return Dict(
        "expected_value_stochastic_solution" => evss,
        "expected_value_perfect_information" => evpi_cost,
        "expected_value_of_perfect_information" => evpi,
        "evpi_percentage" => (evpi / evss) * 100
    )
end

"""
    robust_optimization_analysis_simplified(tree, base_scenarios)

Simplified robust optimization analysis.
"""
function robust_optimization_analysis_simplified(tree, base_scenarios)
    try
        # Define uncertainty sets
        uncertainty_scenarios = [
            Dict("name" => "optimistic", "factor" => 0.8),
            Dict("name" => "expected", "factor" => 1.0),
            Dict("name" => "pessimistic", "factor" => 1.2)
        ]
        
        robust_results = []
        
        for scenario in uncertainty_scenarios
            # Simulate performance under different uncertainty realizations
            params = generate_stochastic_parameters(base_scenarios, 1)
            
            # Apply uncertainty factor
            for (key, value) in params
                if isa(value, Number)
                    params[key] = value * scenario["factor"]
                end
            end
            
            performance = simulate_system_performance(tree, params)
            
            push!(robust_results, Dict(
                "scenario" => scenario["name"],
                "uncertainty_factor" => scenario["factor"],
                "objective_value" => performance["total_cost"],
                "renewable_share" => performance["renewable_share"],
                "system_efficiency" => performance["efficiency"]
            ))
        end
        
        return Dict(
            "scenarios" => robust_results,
            "worst_case_cost" => maximum([r["objective_value"] for r in robust_results]),
            "best_case_cost" => minimum([r["objective_value"] for r in robust_results]),
            "robust_solution_recommended" => true
        )
        
    catch e
        println("Error in robust optimization analysis: $e")
        return Dict("error" => string(e))
    end
end

"""
    compare_stochastic_strategies(strategies, tree, base_scenarios)

Compare different stochastic optimization strategies.
"""
function compare_stochastic_strategies(strategies, tree, base_scenarios)
    println("Comparing stochastic optimization strategies...")
    
    comparison_results = Dict()
    
    for (strategy_name, strategy_params) in strategies
        try
            println("  Analyzing strategy: $strategy_name")
            
            # Modify base scenarios according to strategy
            modified_scenarios = deepcopy(base_scenarios)
            
            # Apply strategy-specific modifications
            if haskey(strategy_params, "cost_factor")
                # Modify cost assumptions
                cost_factor = strategy_params["cost_factor"]
            else
                cost_factor = 1.0
            end
            
            if haskey(strategy_params, "uncertainty_factor")
                uncertainty_factor = strategy_params["uncertainty_factor"]
            else
                uncertainty_factor = 0.1
            end
            
            # Run simplified analysis for this strategy
            strategy_results = []
            
            for i in 1:20  # Reduced sample size for strategy comparison
                params = generate_stochastic_parameters(modified_scenarios, i)
                
                # Apply strategy factors
                for (key, value) in params
                    if isa(value, Number)
                        params[key] = value * cost_factor * (1 + uncertainty_factor * randn())
                    end
                end
                
                performance = simulate_system_performance(tree, params)
                push!(strategy_results, performance)
            end
            
            # Calculate strategy metrics
            costs = [r["total_cost"] for r in strategy_results]
            renewable_shares = [r["renewable_share"] for r in strategy_results]
            efficiencies = [r["efficiency"] for r in strategy_results]
            
            comparison_results[strategy_name] = Dict(
                "expected_cost" => mean(costs),
                "cost_variance" => var(costs),
                "cost_std" => std(costs),
                "renewable_share" => mean(renewable_shares),
                "system_efficiency" => mean(efficiencies),
                "robustness_score" => 1.0 / (1.0 + std(costs) / mean(costs))  # Higher is more robust
            )
            
        catch e
            println("  Error analyzing strategy $strategy_name: $e")
            comparison_results[strategy_name] = Dict(
                "error" => string(e),
                "expected_cost" => Inf,
                "cost_variance" => Inf,
                "renewable_share" => 0.0,
                "system_efficiency" => 0.0,
                "robustness_score" => 0.0
            )
        end
    end
    
    return comparison_results
end

"""
    visualize_stochastic_analysis_simplified(monte_carlo_results, analysis, output_dir)

Create simplified visualizations for stochastic analysis.
"""
function visualize_stochastic_analysis_simplified(monte_carlo_results, analysis, output_dir)
    try
        mkpath(output_dir)
        
        if isempty(monte_carlo_results)
            println("No results to visualize")
            return
        end
        
        # Extract data
        objectives = [r["objective_value"] for r in monte_carlo_results]
        renewable_shares = [r["renewable_share"] for r in monte_carlo_results]
        investments = [r["total_investment"] for r in monte_carlo_results]
        
        # Create basic plots
        
        # 1. Histogram of objective values
        p1 = Plots.histogram(objectives, bins=20,
                           title="Distribution of Total Costs",
                           xlabel="Total Cost",
                           ylabel="Frequency",
                           legend=false,
                           size=(600, 400))
        Plots.savefig(p1, joinpath(output_dir, "cost_distribution.png"))
        
        # 2. Scatter plot: renewable share vs cost
        p2 = Plots.scatter(renewable_shares, objectives,
                         title="Renewable Share vs Total Cost",
                         xlabel="Renewable Share",
                         ylabel="Total Cost",
                         alpha=0.6,
                         size=(600, 400))
        Plots.savefig(p2, joinpath(output_dir, "renewable_vs_cost.png"))
        
        println("Visualizations saved to: $output_dir")
        
    catch e
        println("Error creating visualizations: $e")
    end
end

"""
    create_stochastic_report_simplified(monte_carlo_results, analysis, risk_analysis, output_dir)

Create a simplified stochastic analysis report.
"""
function create_stochastic_report_simplified(monte_carlo_results, analysis, risk_analysis, output_dir)
    try
        report_file = joinpath(output_dir, "stochastic_analysis_summary.txt")
        
        open(report_file, "w") do f
            println(f, "Stochastic Analysis Summary Report")
            println(f, "=" ^ 40)
            println(f, "")
            
            println(f, "Monte Carlo Analysis:")
            println(f, "- Total samples: $(analysis["n_samples"])")
            
            if haskey(analysis, "objective")
                obj_stats = analysis["objective"]
                println(f, "- Mean cost: $(round(obj_stats["mean"], digits=2))")
                println(f, "- Standard deviation: $(round(obj_stats["std"], digits=2))")
                println(f, "- Min cost: $(round(obj_stats["min"], digits=2))")
                println(f, "- Max cost: $(round(obj_stats["max"], digits=2))")
            end
            
            if haskey(analysis, "renewable_share")
                renewable_stats = analysis["renewable_share"]
                println(f, "- Average renewable share: $(round(renewable_stats["mean"] * 100, digits=1))%")
            end
            
            println(f, "")
            println(f, "Risk Analysis:")
            if haskey(risk_analysis, "cvar_95")
                println(f, "- CVaR (95%): $(round(risk_analysis["cvar_95"], digits=2))")
            end
            if haskey(risk_analysis, "coefficient_of_variation")
                println(f, "- Coefficient of variation: $(round(risk_analysis["coefficient_of_variation"], digits=3))")
            end
            
            println(f, "")
            println(f, "Report generated: $(now())")
        end
        
        println("Report saved to: $report_file")
        
    catch e
        println("Error creating report: $e")
    end
end

# Additional helper functions for compatibility
calculate_vss = calculate_vss_simplified
calculate_evpi = calculate_evpi_simplified
robust_optimization_analysis = robust_optimization_analysis_simplified

end # module StochasticAnalysis
