# Lifecycle Analysis Module - handles complete lifecycle analysis and optimization

using .LifeCycleOptimization
using .ScenarioReduction

"""
    run_complete_lifecycle_analysis(years::Int=3, typical_days::Int=4, hours_per_day::Int=6)

Run complete lifecycle analysis with proper multi-timescale parameter handling.
"""
function run_complete_lifecycle_analysis(years::Int=3, typical_days::Int=4, hours_per_day::Int=6)
    println("Running complete lifecycle analysis with multi-timescale parameters...")
    
    try
        # Generate lifecycle scenarios with proper parameter categorization
        lifecycle_scenarios = generate_lifecycle_scenarios(years=years, typical_days=typical_days, hours_per_day=hours_per_day)
        
        # Build scenario tree
        tree, base_scenarios, validation = build_lifecycle_nested_tree(years, typical_days, hours_per_day)
        
        # Generate scenario paths
        paths = NestedScenarioTree.generate_scenario_paths(tree)
        
        # Check if we have valid paths
        if isempty(paths)
            println("Warning: No scenario paths generated, creating mock paths")
            paths = create_mock_paths(years, typical_days, hours_per_day)
        end
        
        # Scenario reduction if needed
        if length(paths) > 50
            println("Reducing scenarios from $(length(paths)) to 50...")
            try
                reduced_paths, selected_indices = ScenarioReduction.reduce_scenario_tree(tree, 50, "fast_forward")
                reduction_quality = ScenarioReduction.validate_reduction_quality(paths, reduced_paths)
                println("Reduction quality: $(reduction_quality)")
                paths = reduced_paths
            catch e
                println("Warning: Scenario reduction failed: $e, using original paths")
            end
        end
        
        # Prepare optimization data with proper timescale categorization
        technology_data = create_multitimescale_technology_data(lifecycle_scenarios)
        demand_data = create_multitimescale_demand_data(lifecycle_scenarios, tree, base_scenarios)
        economic_data = create_multitimescale_economic_data(lifecycle_scenarios)
        
        # Create and solve multi-timescale optimization model
        try
            model, long_term_vars, medium_term_vars, short_term_vars = LifeCycleOptimization.create_multistage_model(
                tree, technology_data, demand_data, economic_data)
            
            optimization_results = LifeCycleOptimization.solve_lifecycle_optimization(
                model, Dict(:long_term => long_term_vars, :medium_term => medium_term_vars, :short_term => short_term_vars))
            
            if optimization_results["status"] in ["optimal", "locally_optimal"]
                # Analyze solution with timescale awareness
                solution_analysis = LifeCycleOptimization.analyze_multitimescale_solution(
                    optimization_results["solution"], tree, paths, lifecycle_scenarios)
                
                # Calculate detailed costs by timescale
                cost_breakdown = LifeCycleOptimization.calculate_multitimescale_costs(
                    optimization_results["solution"], technology_data, economic_data, tree, lifecycle_scenarios)
                
                # Visualize optimization results
                visualize_multitimescale_results(optimization_results, solution_analysis, cost_breakdown, "lifecycle_multitimescale_results")
                
                return tree, paths, optimization_results, solution_analysis, cost_breakdown
            else
                println("Optimization failed with status: $(optimization_results["status"])")
                return tree, paths, nothing, nothing, nothing
            end
        catch e
            println("Error in optimization: $e")
            return tree, paths, nothing, nothing, nothing
        end
    catch e
        println("Error in lifecycle analysis: $e")
        return nothing, [], nothing, nothing, nothing
    end
end

"""
    create_multitimescale_technology_data(lifecycle_scenarios)

Create technology data organized by timescale.
"""
function create_multitimescale_technology_data(lifecycle_scenarios)
    technology_data = Dict()
    
    # Extract timescale-specific technology parameters
    long_term_factors = lifecycle_scenarios["long_term_factors"]
    medium_term_factors = lifecycle_scenarios["medium_term_factors"]
    
    # Long-term technology characteristics
    technology_data["long_term_technologies"] = []
    
    # Component capacities (long-term)
    component_capacities = long_term_factors["component_capacities"]
    for (tech, capacity) in component_capacities
        push!(technology_data["long_term_technologies"], Dict(
            "name" => tech,
            "type" => "capacity_constrained",
            "max_capacity" => capacity,
            "investment_cost" => get_investment_cost(tech),
            "lifetime" => get_technology_lifetime(tech),
            "efficiency" => get_technology_efficiency(tech, long_term_factors)
        ))
    end
    
    # Medium-term cost evolution
    technology_data["cost_evolution"] = medium_term_factors["cost_evolution"]
    
    # Short-term operational parameters
    technology_data["short_term_availability"] = lifecycle_scenarios["short_term_factors"]
    
    return technology_data
end

"""
    create_multitimescale_demand_data(lifecycle_scenarios, tree, base_scenarios)

Create demand data organized by timescale.
"""
function create_multitimescale_demand_data(lifecycle_scenarios, tree, base_scenarios)
    demand_data = Dict()
    
    short_term_factors = lifecycle_scenarios["short_term_factors"]
    medium_term_factors = lifecycle_scenarios["medium_term_factors"]
    long_term_factors = lifecycle_scenarios["long_term_factors"]
    
    # Short-term demand patterns (hourly)
    demand_data["hourly_patterns"] = Dict(
        "electricity_demand" => short_term_factors["electricity_demand_patterns"],
        "thermal_demand" => short_term_factors["thermal_demand_patterns"],
        "transportation_demand" => short_term_factors["transportation_pattern"],
        "hydrogen_demand" => short_term_factors["hydrogen_industry_pattern"],
        "fuel_demand" => short_term_factors["fuel_industry_pattern"]
    )
    
    # Medium-term demand evolution (annual growth)
    demand_data["annual_growth"] = Dict(
        "electricity_growth" => 0.02,  # 2% annual growth
        "thermal_growth" => 0.015,     # 1.5% annual growth
        "transportation_growth" => 0.025, # 2.5% annual growth
        "hydrogen_growth" => 0.05,     # 5% annual growth (rapid growth)
        "fuel_decline" => -0.03        # 3% annual decline (phase out)
    )
    
    # Long-term structural changes
    demand_data["structural_changes"] = Dict(
        "electrification_rate" => long_term_factors["vehicle_fleet_evolution"],
        "efficiency_improvements" => Dict(
            "buildings" => 0.01,      # 1% annual efficiency improvement
            "industry" => 0.015,      # 1.5% annual efficiency improvement
            "transport" => 0.02       # 2% annual efficiency improvement
        )
    )
    
    return demand_data
end

"""
    create_multitimescale_economic_data(lifecycle_scenarios)

Create economic data organized by timescale.
"""
function create_multitimescale_economic_data(lifecycle_scenarios)
    economic_data = Dict()
    
    medium_term_factors = lifecycle_scenarios["medium_term_factors"]
    long_term_factors = lifecycle_scenarios["long_term_factors"]
    
    # Financial parameters
    economic_data["discount_rate"] = 0.05
    economic_data["inflation_rate"] = 0.02
    
    # Medium-term cost evolution
    economic_data["cost_trajectories"] = medium_term_factors["cost_evolution"]
    economic_data["V2G_incentive_evolution"] = medium_term_factors["V2G_incentive_evolution"]
    
    # Long-term policy parameters
    economic_data["carbon_price_trajectory"] = long_term_factors["carbon_price_evolution"]
    economic_data["carbon_intensity_targets"] = long_term_factors["carbon_intensity_targets"]
    economic_data["carbon_reduction_targets"] = long_term_factors["carbon_reduction_targets"]
    
    # Load shedding penalty
    economic_data["load_shed_penalty"] = 1000.0
    
    return economic_data
end

# Helper functions
function get_investment_cost(tech)
    cost_map = Dict(
        "P_solar_rated" => 1200.0,    # $/kW
        "P_wind_rated" => 1500.0,     # $/kW
        "P_heatpump_max" => 800.0,    # $/kW
        "P_electrolysis_max" => 2000.0, # $/kW
        "P_CHP_max" => 1800.0,        # $/kW
        "P_fuelcell_max" => 3000.0    # $/kW
    )
    return get(cost_map, tech, 1000.0)
end

function get_technology_lifetime(tech)
    lifetime_map = Dict(
        "P_solar_rated" => 25,
        "P_wind_rated" => 20,
        "P_heatpump_max" => 15,
        "P_electrolysis_max" => 20,
        "P_CHP_max" => 25,
        "P_fuelcell_max" => 15
    )
    return get(lifetime_map, tech, 20)
end

function get_technology_efficiency(tech, long_term_factors)
    conversion_efficiencies = long_term_factors["conversion_efficiencies"]
    
    efficiency_map = Dict(
        "P_solar_rated" => 0.2,
        "P_wind_rated" => 0.45,
        "P_heatpump_max" => conversion_efficiencies["eta_heatpump"],
        "P_electrolysis_max" => conversion_efficiencies["eta_electrolysis"],
        "P_CHP_max" => conversion_efficiencies["eta_CHP"],
        "P_fuelcell_max" => conversion_efficiencies["eta_fuelcell"]
    )
    return get(efficiency_map, tech, 0.5)
end
