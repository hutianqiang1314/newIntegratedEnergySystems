# Mock Scenario Generator - Create fallback scenarios when generation fails

using DataFrames

"""
    create_fallback_scenarios(years, typical_days, hours_per_day)

Create minimal fallback scenarios when scenario generation fails.
"""
function create_fallback_scenarios(years, typical_days, hours_per_day)
    return Dict(
        "time_structure" => Dict(
            "years" => years,
            "typical_days" => typical_days,
            "hours_per_day" => hours_per_day
        ),
        "annual_data" => Dict(
            "carbon_budget" => [5000.0 * (1.0 - 0.05*(y-1)) for y in 1:years],
            "carbon_price" => [50.0 * (1.0 + 0.05*(y-1)) for y in 1:years]
        ),
        "typical_days_data" => Dict(
            "typical_day_1" => Dict(
                "electricity_load" => fill(0.8, hours_per_day),
                "thermal_load" => fill(0.6, hours_per_day),
                "solar_output" => fill(0.3, hours_per_day),
                "wind_output" => fill(0.5, hours_per_day)
            )
        )
    )
end

"""
    create_mock_paths_three_layer(years, weeks_per_year, days_per_week)

Create mock scenario paths for three-layer time structure when path generation fails.
"""
function create_mock_paths_three_layer(years, weeks_per_year, days_per_week)
    mock_paths = []
    total_scenarios = years * weeks_per_year * days_per_week
    
    for i in 1:total_scenarios
        # Calculate indices for each time layer
        temp = i - 1
        day = (temp % days_per_week) + 1
        temp ÷= days_per_week
        week = (temp % weeks_per_year) + 1
        temp ÷= weeks_per_year
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
        
        week_node = (
            time_index = week,
            data = Dict(
                :weekly_activity_factor => 1.0 + 0.1*sin(2π*(week-1)/52)
            )
        )
        
        day_node = (
            time_index = day,
            data = Dict(
                :day_type => day <= 5 ? "weekday" : "weekend",
                :daily_factor => day <= 5 ? 1.1 : 0.8,
                # Average daily values for 24 hours
                :electricity_load_avg => 0.8 + 0.2*sin(2π*(day-1)/7),
                :thermal_load_avg => 0.6 + 0.1*sin(2π*(day-1)/7),
                :solar_output_avg => 0.3 + 0.2*rand(),
                :wind_output_avg => 0.5 + 0.3*rand()
            )
        )
        
        mock_path = (
            probability = 1.0/total_scenarios,
            nodes = [year_node, week_node, day_node]
        )
        
        push!(mock_paths, mock_path)
    end
    
    return mock_paths
end

"""
    create_mock_paths(years, typical_days, hours_per_day)

Create mock scenario paths when path generation fails.
"""
function create_mock_paths(years, typical_days, hours_per_day)
    mock_paths = []
    total_scenarios = years * typical_days * hours_per_day
    
    for i in 1:total_scenarios
        year = ((i-1) ÷ (typical_days * hours_per_day)) + 1
        day = (((i-1) ÷ hours_per_day) % typical_days) + 1  
        hour = ((i-1) % hours_per_day) + 1
        
        # Create mock nodes with proper structure
        year_node = (
            time_index = year,
            data = Dict(
                :demand_growth => 1.02^(year-1),
                :carbon_budget => 5000.0 * (1.0 - 0.05*(year-1)),
                :carbon_price => 50.0 * (1.0 + 0.05*(year-1))
            )
        )
        
        day_node = (
            time_index = day,
            data = Dict(:day_type => "typical_day_$day")
        )
        
        hour_node = (
            time_index = hour,
            data = Dict(
                :electricity_load => 0.8 + 0.2*sin(2π*hour/24),
                :thermal_load => 0.6 + 0.1*sin(2π*hour/24),
                :solar_output => max(0, sin(π*hour/12)),
                :wind_output => 0.5 + 0.3*rand()
            )
        )
        
        mock_path = (
            probability = 1.0/total_scenarios,
            nodes = [year_node, day_node, hour_node]
        )
        
        push!(mock_paths, mock_path)
    end
    
    return mock_paths
end
