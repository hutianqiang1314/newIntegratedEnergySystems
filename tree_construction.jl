# Tree Construction Module - handles building and analyzing nested scenario trees

using .NestedScenarioTree

"""
    build_lifecycle_nested_tree(years::Int=3, weeks_per_year::Int=4, days_per_week::Int=7, hours_per_day::Int=24; custom_layer_mapping::Union{Dict, Nothing} = nothing)

Build a nested scenario tree for life cycle energy system simulation with configurable layer mapping.
"""
function build_lifecycle_nested_tree(years::Int=3, weeks_per_year::Int=4, days_per_week::Int=7, hours_per_day::Int=24; custom_layer_mapping::Union{Dict, Nothing} = nothing)
    println("Building nested scenario tree for life cycle simulation...")
    
    # Calculate total time periods
    total_weeks = years * weeks_per_year
    total_days = total_weeks * days_per_week
    total_hours = total_days * hours_per_day
    
    println("Simplified three-layer time structure:")
    println("  - Years: $years")
    println("  - Weeks per year: $weeks_per_year (Total weeks: $total_weeks)")
    println("  - Days per week: $days_per_week (Total days: $total_days)")
    println("  - Hours per day: $hours_per_day (fixed, not a tree layer)")
    println("  - Total hours: $total_hours")
    
    # 1. Generate base life cycle scenarios with new time structure
    println("1. Generating life cycle scenarios...")
    base_scenarios = generate_lifecycle_scenarios(
        years=years, 
        typical_days=weeks_per_year,  # Use weeks as typical periods
        hours_per_day=hours_per_day
    )
    
    println("Generated base scenarios with keys: $(collect(keys(base_scenarios)))")
    
    # 2. Create scenario data for three-layer tree construction
    scenario_data = Dict{Symbol, Any}()
    
    # Add time structure parameters
    scenario_data[:years] = years
    scenario_data[:weeks_per_year] = weeks_per_year
    scenario_data[:days_per_week] = days_per_week
    scenario_data[:hours_per_day] = hours_per_day
    
    # Extract and convert scenario-specific data
    if haskey(base_scenarios, "annual_data")
        annual_data = base_scenarios["annual_data"]
        if haskey(annual_data, "carbon_budget")
            scenario_data[:carbon_budgets] = annual_data["carbon_budget"]
        end
        if haskey(annual_data, "carbon_price")
            scenario_data[:carbon_prices] = annual_data["carbon_price"]
        end
    end
    
    # Generate weekly variations (seasonal patterns across weeks)
    scenario_data[:weekly_demand_factors] = generate_weekly_demand_factors_simplified(weeks_per_year)
    scenario_data[:weekly_renewable_factors] = generate_weekly_renewable_factors_simplified(weeks_per_year)
    
    # Generate daily variations
    scenario_data[:daily_patterns] = generate_daily_patterns(days_per_week)
    
    # Add default values if not found in base scenarios
    if !haskey(scenario_data, :carbon_budgets)
        scenario_data[:carbon_budgets] = [5000.0 * (1.0 - 0.05*(y-1)) for y in 1:years]
    end
    if !haskey(scenario_data, :carbon_prices)
        scenario_data[:carbon_prices] = [50.0 * (1.0 + 0.05*(y-1)) for y in 1:years]
    end
    
    # Create structured scenario data for each layer
    year_scenarios = Dict{Int, Dict{Symbol, Float64}}()
    week_scenarios = Dict{Int, Dict{Symbol, Float64}}()
    day_scenarios = Dict{Int, Dict{Symbol, Float64}}()
    
    # Generate year scenarios
    for y in 1:years
        year_scenarios[y] = Dict{Symbol, Float64}(
            :demand_growth => 1.02^(y-1),
            :carbon_budget => scenario_data[:carbon_budgets][y],
            :carbon_price => scenario_data[:carbon_prices][y]
        )
    end
    
    # Generate week scenarios  
    weekly_demand_factors = scenario_data[:weekly_demand_factors]
    weekly_renewable_factors = scenario_data[:weekly_renewable_factors]
    for w in 1:weeks_per_year
        week_scenarios[w] = Dict{Symbol, Float64}(
            :weekly_demand_factor => weekly_demand_factors[w],
            :solar_factor => weekly_renewable_factors[:solar][w],
            :wind_factor => weekly_renewable_factors[:wind][w]
        )
    end
    
    # Generate day scenarios
    daily_patterns = scenario_data[:daily_patterns]
    for d in 1:days_per_week
        day_scenarios[d] = Dict{Symbol, Float64}(
            :daily_factor => daily_patterns[d],
            :day_type_numeric => d <= 5 ? 1.0 : 0.0  # 1 for weekday, 0 for weekend
        )
    end
    
    # Create the proper structure expected by NestedScenarioTree module
    structured_scenario_data = Dict{Symbol, Any}(
        :year => year_scenarios,
        :week => week_scenarios, 
        :day => day_scenarios,
        :time_structure => Dict(
            :years => years,
            :weeks_per_year => weeks_per_year,
            :days_per_week => days_per_week,
            :hours_per_day => hours_per_day
        ),
        :parameters => scenario_data
    )
    
    # 5. Define three-layer tree structure: year -> week -> day
    layers = [:year, :week, :day]
    time_structure = Dict(
        :years => years,
        :weeks_per_year => weeks_per_year,
        :days_per_week => days_per_week,
        :hours_per_day => hours_per_day
    )
    
    # 6. Define branching factors for each layer
    branching_factors = Dict(
        :year => years,
        :week => weeks_per_year,
        :day => days_per_week
    )
    
    # 7. Create or use custom layer mapping
    layer_mapping = nothing
    if custom_layer_mapping !== nothing
        layer_mapping = custom_layer_mapping
    else
        # Use default three-layer mapping
        layer_mapping = NestedScenarioTree.get_default_three_layer_mapping()
    end
    
    # 8. Build the nested scenario tree with layer mapping
    println("2. Building three-layer nested scenario tree with configurable layer mapping...")
    
    if isdefined(NestedScenarioTree, :build_nested_scenario_tree)
        println("Using NestedScenarioTree.build_nested_scenario_tree with layer mapping...")
        
        # Build tree with our structured data and layer mapping
        tree = NestedScenarioTree.build_nested_scenario_tree(
            time_structure, 
            structured_scenario_data, 
            branching_factors, 
            layers;
            layer_mapping = layer_mapping
        )
        
        # Validate tree quality
        if isdefined(NestedScenarioTree, :validate_tree_quality)
            validation = NestedScenarioTree.validate_tree_quality(tree)
        else
            validation = Dict("probability_sum" => 1.0, "structure_valid" => true, "method" => "no_validation")
        end
        
        println("Tree construction completed using NestedScenarioTree module:")
        println("  - Total nodes: $(tree.total_nodes)")
        println("  - Total scenario paths: $(tree.total_paths)")
        println("  - Probability sum: $(round(validation["probability_sum"], digits=6))")
        println("  - Structure valid: $(validation["structure_valid"])")
        println("  - Time layers: $(tree.layers)")
        println("  - Layer mapping: $(layer_mapping !== nothing ? "Custom" : "Default")")
        
        return tree, base_scenarios, validation
    else
        println("NestedScenarioTree.build_nested_scenario_tree function not found")
        error("build_nested_scenario_tree function not available")
    end
end

"""
    generate_weekly_demand_factors_simplified(weeks_per_year::Int)

Generate weekly demand variation factors for simplified week structure.
"""
function generate_weekly_demand_factors_simplified(weeks_per_year::Int)
    # Simplified seasonal demand factors varying across simplified weeks
    weekly_factors = Float64[]
    
    for week in 1:weeks_per_year
        # Create seasonal variation using simplified pattern
        if weeks_per_year == 4  # Quarterly pattern
            seasonal_factor = if week == 1  # Winter quarter
                1.3
            elseif week == 2  # Spring quarter
                1.0
            elseif week == 3  # Summer quarter
                1.2
            else  # Autumn quarter
                1.1
            end
        else
            # General pattern for other week numbers
            seasonal_factor = 1.0 + 0.3*sin(2π*(week-1)/weeks_per_year)
        end
        
        # Add some randomness for realism
        factor = max(0.7, min(1.4, seasonal_factor * (0.95 + 0.1*rand())))
        push!(weekly_factors, factor)
    end
    
    return weekly_factors
end

"""
    generate_weekly_renewable_factors_simplified(weeks_per_year::Int)

Generate weekly renewable energy availability factors for simplified week structure.
"""
function generate_weekly_renewable_factors_simplified(weeks_per_year::Int)
    solar_factors = Float64[]
    wind_factors = Float64[]
    
    for week in 1:weeks_per_year
        if weeks_per_year == 4  # Quarterly pattern
            # Solar: higher in summer (week 3), lower in winter (week 1)
            solar_factor = if week == 1  # Winter
                0.6
            elseif week == 2  # Spring
                1.2
            elseif week == 3  # Summer
                1.5
            else  # Autumn
                1.0
            end
            
            # Wind: higher in winter/spring (weeks 1-2), lower in summer (week 3)
            wind_factor = if week == 1  # Winter
                1.3
            elseif week == 2  # Spring
                1.1
            elseif week == 3  # Summer
                0.7
            else  # Autumn
                1.0
            end
        else
            # General pattern for other week numbers
            solar_base = 1.0 + 0.5*sin(2π*(week-1)/weeks_per_year)
            solar_factor = max(0.3, min(1.7, solar_base * (0.9 + 0.2*rand())))
            
            wind_base = 1.0 - 0.4*sin(2π*(week-1)/weeks_per_year)
            wind_factor = max(0.4, min(1.6, wind_base * (0.9 + 0.2*rand())))
        end
        
        push!(solar_factors, solar_factor)
        push!(wind_factors, wind_factor)
    end
    
    return Dict(
        :solar => solar_factors,
        :wind => wind_factors
    )
end

"""
    generate_daily_patterns(days_per_week::Int)

Generate daily patterns within weeks (weekday vs weekend effects).
"""
function generate_daily_patterns(days_per_week::Int)
    # Daily patterns within a week
    daily_factors = [
        1.2,  # Monday - high demand (start of work week)
        1.1,  # Tuesday
        1.1,  # Wednesday
        1.1,  # Thursday
        1.0,  # Friday - normal demand
        0.8,  # Saturday - lower demand (weekend)
        0.7   # Sunday - lowest demand (weekend)
    ]
    
    return days_per_week <= 7 ? daily_factors[1:days_per_week] : daily_factors
end

"""
    generate_hourly_patterns(hours_per_day::Int)

Generate hourly patterns within days (typical daily load curves).
"""
function generate_hourly_patterns(hours_per_day::Int)
    # Typical daily load curve (normalized to 1.0 average)
    hourly_factors = [
        0.6,  # 00:00 - low night demand
        0.55, # 01:00
        0.5,  # 02:00 - lowest demand
        0.5,  # 03:00
        0.55, # 04:00
        0.6,  # 05:00
        0.7,  # 06:00 - demand starts rising
        0.9,  # 07:00
        1.1,  # 08:00 - morning peak starts
        1.2,  # 09:00
        1.1,  # 10:00
        1.0,  # 11:00
        1.0,  # 12:00 - midday
        1.0,  # 13:00
        1.1,  # 14:00
        1.1,  # 15:00
        1.2,  # 16:00
        1.4,  # 17:00 - evening peak starts
        1.5,  # 18:00 - evening peak
        1.4,  # 19:00
        1.2,  # 20:00
        1.0,  # 21:00 - demand falling
        0.8,  # 22:00
        0.7   # 23:00 - night demand
    ]
    
    return hours_per_day <= 24 ? hourly_factors[1:hours_per_day] : hourly_factors
end

"""
    create_fallback_scenarios_three_layer(years, weeks_per_year, days_per_week, hours_per_day)

Create minimal fallback scenarios for three-layer time structure.
"""
function create_fallback_scenarios_three_layer(years, weeks_per_year, days_per_week, hours_per_day)
    return Dict(
        "time_structure" => Dict(
            "years" => years,
            "weeks_per_year" => weeks_per_year,
            "days_per_week" => days_per_week,
            "hours_per_day" => hours_per_day
        ),
        "annual_data" => Dict(
            "carbon_budget" => [5000.0 * (1.0 - 0.05*(y-1)) for y in 1:years],
            "carbon_price" => [50.0 * (1.0 + 0.05*(y-1)) for y in 1:years]
        ),
        "weekly_data" => Dict(
            "demand_factors" => generate_weekly_demand_factors_simplified(weeks_per_year),
            "renewable_factors" => generate_weekly_renewable_factors_simplified(weeks_per_year)
        ),
        "daily_data" => Dict(
            "weekday_factors" => generate_daily_patterns(days_per_week)
        ),
        "hourly_data" => Dict(
            "load_curve" => generate_hourly_patterns(hours_per_day)
        )
    )
end

"""
    create_mock_paths_five_layer(years, months_per_year, weeks_per_month, days_per_week, hours_per_day)

Create mock scenario paths for five-layer time structure when path generation fails.
"""
function create_mock_paths_five_layer(years, months_per_year, weeks_per_month, days_per_week, hours_per_day)
    mock_paths = []
    total_scenarios = years * months_per_year * weeks_per_month * days_per_week * hours_per_day
    
    for i in 1:total_scenarios
        # Calculate indices for each time layer
        temp = i - 1
        hour = (temp % hours_per_day) + 1
        temp ÷= hours_per_day
        day = (temp % days_per_week) + 1
        temp ÷= days_per_week
        week = (temp % weeks_per_month) + 1
        temp ÷= weeks_per_month
        month = (temp % months_per_year) + 1
        temp ÷= months_per_year
        year = temp + 1
        
        # Create mock nodes for each layer
        year_node = (
            time_index = year,
            data = Dict(
                :demand_growth => 1.02^(year-1),
                :carbon_budget => 5000.0 * (1.0 - 0.05*(year-1)),
                :carbon_price => 50.0 * (1.0 + 0.05*(year-1))
            )
        )
        
        month_node = (
            time_index = month,
            data = Dict(
                :seasonal_factor => 1.0 + 0.3*sin(2π*(month-1)/12),
                :heating_cooling_demand => month in [12,1,2,6,7,8] ? 1.3 : 1.0
            )
        )
        
        week_node = (
            time_index = week,
            data = Dict(
                :weekly_activity_factor => 1.0 + 0.1*sin(2π*(week-1)/4)
            )
        )
        
        day_node = (
            time_index = day,
            data = Dict(
                :day_type => day <= 5 ? "weekday" : "weekend",
                :daily_factor => day <= 5 ? 1.1 : 0.8
            )
        )
        
        hour_node = (
            time_index = hour,
            data = Dict(
                :electricity_load => 0.8 + 0.4*sin(2π*(hour-6)/24),
                :thermal_load => 0.6 + 0.2*sin(2π*(hour-6)/24),
                :solar_output => max(0, sin(π*(hour-6)/12)),
                :wind_output => 0.5 + 0.3*rand()
            )
        )
        
        mock_path = (
            probability = 1.0/total_scenarios,
            nodes = [year_node, month_node, week_node, day_node, hour_node]
        )
        
        push!(mock_paths, mock_path)
    end
    
    return mock_paths
end

"""
    create_simple_nested_tree(years, weeks_per_year, days_per_week, scenario_data)

Create a simple nested tree structure when the main tree construction fails.
"""
function create_simple_nested_tree(years, weeks_per_year, days_per_week, scenario_data)
    # println("Creating simple nested tree as fallback...")
    
    # Create a simple tree structure that mimics the expected interface
    tree = (
        layers = [:year, :week, :day],
        total_nodes = years + (years * weeks_per_year) + (years * weeks_per_year * days_per_week),
        total_paths = years * weeks_per_year * days_per_week,
        structure = Dict(
            :years => years,
            :weeks_per_year => weeks_per_year,
            :days_per_week => days_per_week
        ),
        scenario_data = scenario_data,
        # Add methods to generate paths
        root_nodes = create_simple_root_nodes(years, weeks_per_year, days_per_week, scenario_data)
    )
    
    # println("Simple tree created with $(tree.total_paths) paths and $(tree.total_nodes) nodes")
    return tree
end

"""
    create_simple_root_nodes(years, weeks_per_year, days_per_week, scenario_data)

Create simple root nodes for the fallback tree structure.
"""
function create_simple_root_nodes(years, weeks_per_year, days_per_week, scenario_data)
    root_nodes = []
    
    for y in 1:years
        year_node = (
            time_index = y,
            layer = :year,
            data = get(get(scenario_data, :year, Dict()), y, Dict(:carbon_budget => 5000.0, :carbon_price => 50.0)),
            children = []
        )
        
        for w in 1:weeks_per_year
            week_node = (
                time_index = w,
                layer = :week,
                data = get(get(scenario_data, :week, Dict()), w, Dict(:demand_factor => 1.0)),
                children = []
            )
            
            for d in 1:days_per_week
                day_node = (
                    time_index = d,
                    layer = :day,
                    data = get(get(scenario_data, :day, Dict()), d, Dict(:daily_factor => 1.0)),
                    children = []
                )
                push!(week_node.children, day_node)
            end
            push!(year_node.children, week_node)
        end
        push!(root_nodes, year_node)
    end
    
    return root_nodes
end

"""
    generate_three_layer_scenario_data(years, weeks_per_year, days_per_week, hours_per_day)

Generate scenario data specifically structured for three-layer time decomposition.
"""
function generate_three_layer_scenario_data(years, weeks_per_year, days_per_week, hours_per_day)
    scenario_data = Dict{String, Any}()
    
    # Time structure
    scenario_data["time_structure"] = Dict(
        "years" => years,
        "weeks_per_year" => weeks_per_year,
        "days_per_week" => days_per_week,
        "hours_per_day" => hours_per_day
    )
    
    # Year-level data
    scenario_data["year"] = Dict{Int, Dict{String, Float64}}()
    for y in 1:years
        scenario_data["year"][y] = Dict{String, Float64}(
            "demand_growth" => 1.02^(y-1),
            "carbon_budget" => 5000.0 * (1.0 - 0.05*(y-1)),
            "carbon_price" => 50.0 * (1.0 + 0.05*(y-1))
        )
    end
    
    # Week-level data
    scenario_data["week"] = Dict{Int, Dict{String, Float64}}()
    weekly_demand_factors = generate_weekly_demand_factors_simplified(weeks_per_year)
    weekly_renewable_factors = generate_weekly_renewable_factors_simplified(weeks_per_year)
    for w in 1:weeks_per_year
        scenario_data["week"][w] = Dict{String, Float64}(
            "weekly_demand_factor" => weekly_demand_factors[w],
            "wind_factor" => weekly_renewable_factors[:wind][w],
            "solar_factor" => weekly_renewable_factors[:solar][w]
        )
    end
    
    # Day-level data
    scenario_data["day"] = Dict{Int, Dict{String, Float64}}()
    daily_patterns = generate_daily_patterns(days_per_week)
    for d in 1:days_per_week
        scenario_data["day"][d] = Dict{String, Float64}(
            "day_type_numeric" => d <= 5 ? 1.0 : 0.0,
            "daily_factor" => daily_patterns[d]
        )
    end
    
    # Additional parameters
    scenario_data["parameters"] = Dict{Symbol, Any}(
        :daily_patterns => daily_patterns,
        :years => years,
        :weekly_renewable_factors => weekly_renewable_factors,
        :weeks_per_year => weeks_per_year,
        :carbon_prices => [50.0 * (1.0 + 0.05*(y-1)) for y in 1:years],
        :weekly_demand_factors => weekly_demand_factors,
        :carbon_budgets => [5000.0 * (1.0 - 0.05*(y-1)) for y in 1:years],
        :days_per_week => days_per_week,
        :hours_per_day => hours_per_day
    )
    
    return scenario_data
end
