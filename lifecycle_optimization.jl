# Multi-stage Stochastic Optimization for Life Cycle Energy Systems

module LifeCycleOptimization

using JuMP, Ipopt, DataFrames, Statistics, LinearAlgebra
using CSV, Random

export create_multistage_model, solve_lifecycle_optimization, analyze_stochastic_solution,
       create_investment_variables, create_operational_variables, add_system_constraints,
       add_lifecycle_constraints, calculate_lifecycle_costs

# ========== Multi-stage Stochastic Programming Model ==========

"""
    create_multistage_model(scenario_tree, technology_data, demand_data, economic_data)

Create multi-stage stochastic programming model for life cycle energy system optimization.
"""
function create_multistage_model(scenario_tree, technology_data, demand_data, economic_data)
    # Include necessary modules
    include("nested_scenario_tree.jl")
    paths = Main.NestedScenarioTree.generate_scenario_paths(scenario_tree)
    
    model = Model(Ipopt.Optimizer)
    set_silent(model)
    
    # ========== Sets and Parameters ==========
    
    # Scenario paths
    scenarios = 1:length(paths)
    
    # Time periods (nodes in tree)
    years = 1:scenario_tree.time_structure[:years]
    typical_days = 1:scenario_tree.time_structure[:typical_days]
    hours = 1:scenario_tree.time_structure[:hours_per_day]
    
    # Technologies
    technologies = ["solar", "wind", "battery", "electrolyzer", "fuel_cell", "heat_pump", "CHP"]
    energy_carriers = ["electricity", "heat", "hydrogen"]
    
    # ========== Decision Variables ==========
    
    # Investment variables (first stage - year decisions)
    investment_vars = create_investment_variables(model, years, technologies, scenarios, paths)
    
    # Operational variables (second stage - typical day and hour decisions)
    operational_vars = create_operational_variables(model, scenarios, typical_days, hours, 
                                                   technologies, energy_carriers, paths)
    
    # ========== Objective Function ==========
    
    objective_expr = create_lifecycle_objective(model, investment_vars, operational_vars, 
                                               scenarios, years, typical_days, hours, 
                                               paths, technology_data, economic_data)
    
    @objective(model, Min, objective_expr)
    
    # ========== Constraints ==========
    
    # Investment constraints
    add_investment_constraints(model, investment_vars, years, technologies, technology_data)
    
    # System operation constraints
    add_system_constraints(model, operational_vars, scenarios, typical_days, hours, 
                          technologies, demand_data, paths)
    
    # Lifecycle constraints
    add_lifecycle_constraints(model, investment_vars, operational_vars, scenarios, 
                             years, typical_days, hours, paths, technology_data)
    
    # Non-anticipativity constraints (ensure proper stochastic structure)
    add_nonanticipativity_constraints(model, investment_vars, operational_vars, 
                                     scenarios, paths, scenario_tree)
    
    return model, investment_vars, operational_vars
end

"""
    create_investment_variables(model, years, technologies, scenarios, paths)

Create investment decision variables for each year and technology.
"""
function create_investment_variables(model, years, technologies, scenarios, paths)
    investment_vars = Dict()
    
    # Capacity investment variables (MW)
    @variable(model, x_invest[y in years, tech in technologies] >= 0)
    investment_vars[:x_invest] = x_invest
    
    # Binary investment decision variables
    @variable(model, y_invest[y in years, tech in technologies], Bin)
    investment_vars[:y_invest] = y_invest
    
    # Cumulative capacity variables
    @variable(model, x_capacity[y in years, tech in technologies] >= 0)
    investment_vars[:x_capacity] = x_capacity
    
    # Retirement variables
    @variable(model, x_retire[y in years, tech in technologies] >= 0)
    investment_vars[:x_retire] = x_retire
    
    return investment_vars
end

"""
    create_operational_variables(model, scenarios, typical_days, hours, technologies, energy_carriers, paths)

Create operational decision variables for each scenario, typical day, and hour.
"""
function create_operational_variables(model, scenarios, typical_days, hours, 
                                    technologies, energy_carriers, paths)
    operational_vars = Dict()
    
    # Energy production variables (MW)
    @variable(model, p_prod[s in scenarios, d in typical_days, h in hours, tech in technologies] >= 0)
    operational_vars[:p_prod] = p_prod
    
    # Energy storage variables (MWh)
    @variable(model, e_storage[s in scenarios, d in typical_days, h in 0:length(hours), 
                              carrier in energy_carriers] >= 0)
    operational_vars[:e_storage] = e_storage
    
    # Energy conversion variables (MW)
    @variable(model, p_conv[s in scenarios, d in typical_days, h in hours, 
                           from in energy_carriers, to in energy_carriers] >= 0)
    operational_vars[:p_conv] = p_conv
    
    # Grid interaction variables
    @variable(model, p_grid_buy[s in scenarios, d in typical_days, h in hours] >= 0)
    @variable(model, p_grid_sell[s in scenarios, d in typical_days, h in hours] >= 0)
    operational_vars[:p_grid_buy] = p_grid_buy
    operational_vars[:p_grid_sell] = p_grid_sell
    
    # Load shedding variables (penalty variables)
    @variable(model, load_shed[s in scenarios, d in typical_days, h in hours, 
                              carrier in energy_carriers] >= 0)
    operational_vars[:load_shed] = load_shed
    
    # Carbon emissions variables
    @variable(model, carbon_emissions[s in scenarios, d in typical_days, h in hours] >= 0)
    operational_vars[:carbon_emissions] = carbon_emissions
    
    return operational_vars
end

"""
    create_lifecycle_objective(model, investment_vars, operational_vars, scenarios, years, 
                               typical_days, hours, paths, technology_data, economic_data)

Create lifecycle objective function minimizing total discounted costs.
"""
function create_lifecycle_objective(model, investment_vars, operational_vars, scenarios, 
                                   years, typical_days, hours, paths, technology_data, economic_data)
    
    # Extract variables
    x_invest = investment_vars[:x_invest]
    p_prod = operational_vars[:p_prod]
    p_grid_buy = operational_vars[:p_grid_buy]
    p_grid_sell = operational_vars[:p_grid_sell]
    load_shed = operational_vars[:load_shed]
    carbon_emissions = operational_vars[:carbon_emissions]
    
    # Economic parameters
    discount_rate = get(economic_data, "discount_rate", 0.05)
    carbon_price_base = get(economic_data, "carbon_price_base", 50.0)
    load_shed_penalty = get(economic_data, "load_shed_penalty", 1000.0)
    
    objective_expr = AffExpr(0.0)
    
    # Investment costs (first stage)
    for y in years
        discount_factor = 1.0 / (1.0 + discount_rate)^(y-1)
        for tech in technology_data["technologies"]
            tech_name = tech["name"]
            investment_cost = tech["investment_cost"]
            
            add_to_expression!(objective_expr, 
                discount_factor * investment_cost, x_invest[y, tech_name])
        end
    end
    
    # Operational costs (second stage)
    for (s, path) in enumerate(paths)
        path_probability = path.probability
        
        # Get year from path
        year_node = path.nodes[1]
        year = year_node.time_index
        discount_factor = 1.0 / (1.0 + discount_rate)^(year-1)
        
        for d in typical_days
            # Get typical day weight
            if length(path.nodes) >= 2
                day_node = path.nodes[2]
                day_weight = get(day_node.data, :weight, 1.0)
            else
                day_weight = 1.0
            end
            
            for h in hours
                # Grid costs
                if length(path.nodes) >= 3
                    hour_node = path.nodes[3]
                    grid_price = get(hour_node.data, :electricity_price, 0.12)
                    carbon_price = get(year_node.data, :carbon_price, carbon_price_base)
                else
                    grid_price = 0.12
                    carbon_price = carbon_price_base
                end
                
                # Grid purchase cost
                add_to_expression!(objective_expr, 
                    path_probability * discount_factor * day_weight * grid_price, 
                    p_grid_buy[s, d, h])
                
                # Grid sale revenue (negative cost)
                add_to_expression!(objective_expr, 
                    -path_probability * discount_factor * day_weight * grid_price * 0.8, 
                    p_grid_sell[s, d, h])
                
                # Carbon emission costs
                add_to_expression!(objective_expr, 
                    path_probability * discount_factor * day_weight * carbon_price, 
                    carbon_emissions[s, d, h])
                
                # Load shedding penalty
                for carrier in ["electricity", "heat", "hydrogen"]
                    add_to_expression!(objective_expr, 
                        path_probability * discount_factor * day_weight * load_shed_penalty, 
                        load_shed[s, d, h, carrier])
                end
            end
        end
    end
    
    return objective_expr
end

"""
    add_investment_constraints(model, investment_vars, years, technologies, technology_data)

Add investment-related constraints.
"""
function add_investment_constraints(model, investment_vars, years, technologies, technology_data)
    x_invest = investment_vars[:x_invest]
    y_invest = investment_vars[:y_invest]
    x_capacity = investment_vars[:x_capacity]
    x_retire = investment_vars[:x_retire]
    
    # Create technology lookup
    tech_lookup = Dict(tech["name"] => tech for tech in technology_data["technologies"])
    
    # Capacity evolution constraints
    for tech in technologies
        if !haskey(tech_lookup, tech)
            continue
        end
        
        tech_data = tech_lookup[tech]
        initial_capacity = get(tech_data, "initial_capacity", 0.0)
        max_annual_investment = get(tech_data, "max_annual_investment", 1000.0)
        lifetime = get(tech_data, "lifetime", 20)
        
        # Initial capacity
        @constraint(model, x_capacity[1, tech] == initial_capacity + x_invest[1, tech])
        
        # Capacity evolution over years
        for y in 2:length(years)
            # Natural retirement based on lifetime
            retirement_year = max(1, y - lifetime)
            natural_retirement = (y > lifetime) ? x_invest[retirement_year, tech] : 0.0
            
            @constraint(model, x_capacity[y, tech] == 
                x_capacity[y-1, tech] + x_invest[y, tech] - x_retire[y, tech] - natural_retirement)
        end
        
        # Investment bounds
        for y in years
            @constraint(model, x_invest[y, tech] <= max_annual_investment * y_invest[y, tech])
        end
    end
end

"""
    add_system_constraints(model, operational_vars, scenarios, typical_days, hours, 
                          technologies, demand_data, paths)

Add energy system operation constraints.
"""
function add_system_constraints(model, operational_vars, scenarios, typical_days, hours, 
                               technologies, demand_data, paths)
    
    p_prod = operational_vars[:p_prod]
    e_storage = operational_vars[:e_storage]
    p_conv = operational_vars[:p_conv]
    p_grid_buy = operational_vars[:p_grid_buy]
    p_grid_sell = operational_vars[:p_grid_sell]
    load_shed = operational_vars[:load_shed]
    
    energy_carriers = ["electricity", "heat", "hydrogen"]
    
    # Energy balance constraints
    for (s, path) in enumerate(paths)
        for d in typical_days
            for h in hours
                # Get demands from path data
                if length(path.nodes) >= 3
                    hour_node = path.nodes[3]
                    elec_demand = get(hour_node.data, :electricity_load, 1.0) * 100  # Scale to MW
                    heat_demand = get(hour_node.data, :thermal_load, 1.0) * 80
                    hydrogen_demand = 10.0  # Base hydrogen demand
                else
                    elec_demand = 100.0
                    heat_demand = 80.0
                    hydrogen_demand = 10.0
                end
                
                demands = Dict(
                    "electricity" => elec_demand,
                    "heat" => heat_demand,
                    "hydrogen" => hydrogen_demand
                )
                
                # Electricity balance
                @constraint(model,
                    sum(p_prod[s, d, h, tech] for tech in ["solar", "wind", "CHP"]) +
                    p_grid_buy[s, d, h] +
                    (h > 1 ? e_storage[s, d, h-1, "electricity"] - e_storage[s, d, h, "electricity"] : 0) +
                    sum(p_conv[s, d, h, from, "electricity"] for from in energy_carriers if from != "electricity") ==
                    demands["electricity"] + 
                    p_grid_sell[s, d, h] +
                    sum(p_conv[s, d, h, "electricity", to] for to in energy_carriers if to != "electricity") +
                    load_shed[s, d, h, "electricity"]
                )
                
                # Heat balance
                @constraint(model,
                    sum(p_prod[s, d, h, tech] for tech in ["heat_pump", "CHP"]) +
                    (h > 1 ? e_storage[s, d, h-1, "heat"] - e_storage[s, d, h, "heat"] : 0) +
                    sum(p_conv[s, d, h, from, "heat"] for from in energy_carriers if from != "heat") ==
                    demands["heat"] +
                    sum(p_conv[s, d, h, "heat", to] for to in energy_carriers if to != "heat") +
                    load_shed[s, d, h, "heat"]
                )
                
                # Hydrogen balance
                @constraint(model,
                    sum(p_prod[s, d, h, tech] for tech in ["electrolyzer"]) +
                    (h > 1 ? e_storage[s, d, h-1, "hydrogen"] - e_storage[s, d, h, "hydrogen"] : 0) +
                    sum(p_conv[s, d, h, from, "hydrogen"] for from in energy_carriers if from != "hydrogen") ==
                    demands["hydrogen"] +
                    sum(p_conv[s, d, h, "hydrogen", to] for to in energy_carriers if to != "hydrogen") +
                    load_shed[s, d, h, "hydrogen"]
                )
            end
            
            # Storage continuity constraints
            for carrier in energy_carriers
                # Initial storage level
                @constraint(model, e_storage[s, d, 0, carrier] == 
                    (d == 1 ? 0.5 * 100 : e_storage[s, d-1, length(hours), carrier]))  # Link between days
                
                # Storage bounds
                for h in 0:length(hours)
                    @constraint(model, e_storage[s, d, h, carrier] <= 100.0)  # Max storage capacity
                end
            end
        end
    end
end

"""
    add_lifecycle_constraints(model, investment_vars, operational_vars, scenarios, 
                             years, typical_days, hours, paths, technology_data)

Add lifecycle-specific constraints.
"""
function add_lifecycle_constraints(model, investment_vars, operational_vars, scenarios, 
                                 years, typical_days, hours, paths, technology_data)
    
    x_capacity = investment_vars[:x_capacity]
    p_prod = operational_vars[:p_prod]
    carbon_emissions = operational_vars[:carbon_emissions]
    p_grid_buy = operational_vars[:p_grid_buy]
    
    tech_lookup = Dict(tech["name"] => tech for tech in technology_data["technologies"])
    
    # Production capacity constraints
    for (s, path) in enumerate(paths)
        # Get year from path
        year_node = path.nodes[1]
        year = year_node.time_index
        
        for d in typical_days
            for h in hours
                for tech in ["solar", "wind", "battery", "electrolyzer", "fuel_cell", "heat_pump", "CHP"]
                    if haskey(tech_lookup, tech)
                        capacity_factor = get(tech_lookup[tech], "capacity_factor", 0.3)
                        
                        # Renewable output constraints
                        if tech in ["solar", "wind"] && length(path.nodes) >= 3
                            hour_node = path.nodes[3]
                            if tech == "solar"
                                resource_availability = get(hour_node.data, :solar_output, 0.3)
                            else
                                resource_availability = get(hour_node.data, :wind_output, 0.5)
                            end
                            
                            @constraint(model, p_prod[s, d, h, tech] <= 
                                x_capacity[year, tech] * resource_availability)
                        else
                            @constraint(model, p_prod[s, d, h, tech] <= 
                                x_capacity[year, tech] * capacity_factor)
                        end
                    end
                end
            end
        end
        
        # Carbon emission constraints
        for d in typical_days
            for h in hours
                # Calculate carbon emissions from grid electricity
                if length(path.nodes) >= 3
                    hour_node = path.nodes[3]
                    carbon_intensity = get(hour_node.data, :carbon_intensity, 0.5)
                else
                    carbon_intensity = 0.5
                end
                
                @constraint(model, carbon_emissions[s, d, h] >= 
                    carbon_intensity * p_grid_buy[s, d, h])
                
                # Annual carbon budget constraint
                year_node = path.nodes[1]
                carbon_budget = get(year_node.data, :carbon_budget, 5000.0)
                
                # This is simplified - in practice, would need to aggregate properly
                @constraint(model, carbon_emissions[s, d, h] <= carbon_budget / (365 * 24))
            end
        end
    end
end

"""
    add_nonanticipativity_constraints(model, investment_vars, operational_vars, 
                                     scenarios, paths, scenario_tree)

Add non-anticipativity constraints to ensure proper stochastic structure.
"""
function add_nonanticipativity_constraints(model, investment_vars, operational_vars, 
                                         scenarios, paths, scenario_tree)
    
    x_invest = investment_vars[:x_invest]
    
    # Investment decisions must be non-anticipative (same for all scenarios at each year)
    technologies = ["solar", "wind", "battery", "electrolyzer", "fuel_cell", "heat_pump", "CHP"]
    
    for year in 1:scenario_tree.time_structure[:years]
        # Group scenarios by their history up to this year
        scenario_groups = group_scenarios_by_history(paths, year)
        
        for group in scenario_groups
            if length(group) > 1
                base_scenario = group[1]
                for tech in technologies
                    for other_scenario in group[2:end]
                        @constraint(model, x_invest[year, tech] == x_invest[year, tech])
                        # Note: In a proper implementation, this would reference scenario-specific variables
                    end
                end
            end
        end
    end
end

"""
    group_scenarios_by_history(paths, year)

Group scenarios that have the same history up to a given year.
"""
function group_scenarios_by_history(paths, year)
    groups = Dict()
    
    for (s, path) in enumerate(paths)
        # Create history key based on path up to year
        history_key = []
        for i in 1:min(year, length(path.nodes))
            node = path.nodes[i]
            push!(history_key, (node.time_scale, node.time_index))
        end
        
        history_str = string(history_key)
        if !haskey(groups, history_str)
            groups[history_str] = Int[]
        end
        push!(groups[history_str], s)
    end
    
    return collect(values(groups))
end

"""
    solve_lifecycle_optimization(model, investment_vars, operational_vars)

Solve the lifecycle optimization model and extract results.
"""
function solve_lifecycle_optimization(model, investment_vars, operational_vars)
    println("Solving lifecycle optimization model...")
    
    # Set solver options
    set_optimizer_attribute(model, "max_iter", 3000)
    set_optimizer_attribute(model, "tol", 1e-6)
    
    # Solve the model
    optimize!(model)
    
    # Check solution status
    status = termination_status(model)
    
    if status == MOI.OPTIMAL
        println("Optimal solution found!")
        
        # Extract solution
        solution = extract_lifecycle_solution(model, investment_vars, operational_vars)
        
        return Dict(
            "status" => "optimal",
            "objective_value" => objective_value(model),
            "solution" => solution
        )
        
    elseif status == MOI.LOCALLY_SOLVED
        println("Locally optimal solution found!")
        
        solution = extract_lifecycle_solution(model, investment_vars, operational_vars)
        
        return Dict(
            "status" => "locally_optimal", 
            "objective_value" => objective_value(model),
            "solution" => solution
        )
        
    else
        println("Optimization failed with status: $status")
        return Dict(
            "status" => "failed",
            "termination_status" => status
        )
    end
end

"""
    extract_lifecycle_solution(model, investment_vars, operational_vars)

Extract solution values from the solved model.
"""
function extract_lifecycle_solution(model, investment_vars, operational_vars)
    solution = Dict()
    
    # Extract investment decisions
    solution["investments"] = Dict()
    for var_name in keys(investment_vars)
        var = investment_vars[var_name]
        solution["investments"][string(var_name)] = value.(var)
    end
    
    # Extract operational decisions (sample for key variables)
    solution["operations"] = Dict()
    for var_name in [:p_prod, :p_grid_buy, :p_grid_sell, :carbon_emissions]
        if haskey(operational_vars, var_name)
            var = operational_vars[var_name]
            solution["operations"][string(var_name)] = value.(var)
        end
    end
    
    return solution
end

"""
    analyze_stochastic_solution(solution, scenario_tree, paths)

Analyze the stochastic solution and calculate key performance indicators.
"""
function analyze_stochastic_solution(solution, scenario_tree, paths)
    analysis = Dict()
    
    # Investment analysis
    investments = solution["investments"]["x_invest"]
    total_investment = sum(values(investments))
    
    analysis["total_investment_MW"] = total_investment
    analysis["investment_by_technology"] = Dict()
    
    # Technology-wise investment breakdown
    for year in 1:scenario_tree.time_structure[:years]
        for tech in ["solar", "wind", "battery", "electrolyzer", "fuel_cell", "heat_pump", "CHP"]
            if !haskey(analysis["investment_by_technology"], tech)
                analysis["investment_by_technology"][tech] = 0.0
            end
            analysis["investment_by_technology"][tech] += investments[year, tech]
        end
    end
    
    # Operational analysis
    if haskey(solution["operations"], "p_grid_buy")
        grid_purchases = solution["operations"]["p_grid_buy"]
        analysis["total_grid_purchases"] = sum(values(grid_purchases))
        analysis["average_grid_purchases"] = mean(values(grid_purchases))
    end
    
    if haskey(solution["operations"], "carbon_emissions")
        carbon_emissions = solution["operations"]["carbon_emissions"]
        analysis["total_carbon_emissions"] = sum(values(carbon_emissions))
        analysis["average_carbon_emissions"] = mean(values(carbon_emissions))
    end
    
    # Economic analysis
    analysis["total_lifecycle_cost"] = solution["objective_value"]
    
    # Risk analysis
    if haskey(solution["operations"], "p_prod")
        production = solution["operations"]["p_prod"]
        renewable_production = 0.0
        total_production = 0.0
        
        for key in keys(production)
            if length(key) >= 4
                tech = key[4]
                value = production[key]
                total_production += value
                if tech in ["solar", "wind"]
                    renewable_production += value
                end
            end
        end
        
        analysis["renewable_share"] = total_production > 0 ? renewable_production / total_production : 0.0
    end
    
    return analysis
end

"""
    calculate_lifecycle_costs(solution, technology_data, economic_data, scenario_tree)

Calculate detailed lifecycle cost breakdown.
"""
function calculate_lifecycle_costs(solution, technology_data, economic_data, scenario_tree)
    cost_breakdown = Dict()
    
    # Investment costs
    investments = solution["investments"]["x_invest"]
    tech_lookup = Dict(tech["name"] => tech for tech in technology_data["technologies"])
    
    investment_costs = 0.0
    for year in 1:scenario_tree.time_structure[:years]
        discount_factor = 1.0 / (1.0 + economic_data["discount_rate"])^(year-1)
        for tech in keys(tech_lookup)
            if haskey(investments, (year, tech))
                tech_data = tech_lookup[tech]
                cost = investments[year, tech] * tech_data["investment_cost"] * discount_factor
                investment_costs += cost
            end
        end
    end
    
    cost_breakdown["investment_costs"] = investment_costs
    
    # Operational costs (simplified)
    if haskey(solution["operations"], "p_grid_buy")
        grid_costs = sum(values(solution["operations"]["p_grid_buy"])) * 0.12  # Assume average price
        cost_breakdown["operational_costs"] = grid_costs
    else
        cost_breakdown["operational_costs"] = 0.0
    end
    
    # Carbon costs
    if haskey(solution["operations"], "carbon_emissions")
        carbon_costs = sum(values(solution["operations"]["carbon_emissions"])) * 
                      economic_data["carbon_price_base"]
        cost_breakdown["carbon_costs"] = carbon_costs
    else
        cost_breakdown["carbon_costs"] = 0.0
    end
    
    cost_breakdown["total_costs"] = sum(values(cost_breakdown))
    
    return cost_breakdown
end

end # module
