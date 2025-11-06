# typical_days.jl
# Typical Day Data Processing Module

using CSV
using DataFrames
using Dates

"""
    load_typical_day_data(filepath::String)

Load typical day data from CSV file
"""
function load_typical_day_data(filepath::String)
    return CSV.read(filepath, DataFrame)
end

"""
    get_typical_day_weights()

Get weights (representative days) for each typical day
Returns: Dict{String, Float64} - Mapping from typical day ID to weight
"""
function get_typical_day_weights()
    # Example weight configuration
    return Dict(
        "winter_weekday" => 64.0,
        "winter_weekend" => 26.0,
        "spring_weekday" => 65.0,
        "spring_weekend" => 26.0,
        "summer_weekday" => 65.0,
        "summer_weekend" => 27.0,
        "autumn_weekday" => 65.0,
        "autumn_weekend" => 27.0
    )
end

"""
    prepare_typical_day_parameters(typical_day_id::String, data::DataFrame)

Prepare model parameters for a specified typical day
"""
function prepare_typical_day_parameters(typical_day_id::String, data::DataFrame)
    # Start with base parameters
    params = create_sample_parameters()
    
    # Filter data by typical day ID
    day_data = filter(row -> row.typical_day_id == typical_day_id, data)
    
    if nrow(day_data) == 0
        error("No data found for typical day: $typical_day_id")
    end
    
    # Update time series parameters
    T = nrow(day_data)
    params["T"] = T
    
    # Update renewable energy data (using rated capacity multipliers)
    params["P_solar_max"] = day_data.solar_potential .* params["P_solar_rated"]
    params["P_wind_max"] = day_data.wind_potential .* params["P_wind_rated"]
    
    # Update electricity demand data
    params["P_industry_elec_base"] = day_data.electricity_industry_load
    params["P_buildings_elec_base"] = day_data.electricity_buildings_load
    
    # Update thermal demand data
    params["Q_industry_th_base"] = day_data.thermal_industry_load
    params["Q_buildings_th_base"] = day_data.thermal_buildings_load
    
    # Update transportation demand
    params["D_total"] = day_data.transportation_demand
    
    # Update industry demands
    params["H_industry_base"] = day_data.hydrogen_industry_demand
    params["F_industry_base"] = day_data.fuel_industry_demand
    
    # Update electricity price and carbon intensity
    params["c_grid"] = day_data.electricity_price
    params["gamma_elec"] = day_data.carbon_intensity

    # Return updated parameters
    return params
end

"""
    get_typical_day_ids()

Get a list of all typical day IDs
"""
function get_typical_day_ids()
    return ["winter_weekday", "winter_weekend", 
            "spring_weekday", "spring_weekend", 
            "summer_weekday", "summer_weekend", 
            "autumn_weekday", "autumn_weekend"]
end


# calendar_mapping.jl
# Calendar Mapping Module

using Dates

"""
    create_yearly_calendar(year::Int=2025)

Create an annual calendar with seasonal and day type information
"""
function create_yearly_calendar(year::Int=2025)
    start_date = Date(year, 1, 1)
    end_date = Date(year, 12, 31)
    
    calendar = []
    
    for date in start_date:Day(1):end_date
        # Determine season
        month = Dates.month(date)
        if 3 <= month <= 5
            season = "spring"
        elseif 6 <= month <= 8
            season = "summer"
        elseif 9 <= month <= 11
            season = "autumn"
        else
            season = "winter"
        end
        
        # Determine day type
        day_of_week = dayofweek(date)
        if day_of_week in [6, 7]  # Saturday and Sunday
            day_type = "weekend"
        else
            day_type = "weekday"
        end
        
        push!(calendar, Dict(
            "date" => date,
            "season" => season,
            "day_type" => day_type
        ))
    end
    
    return calendar
end

"""
    map_calendar_to_typical_days(calendar::Vector{Any})

Map calendar to typical days
"""
function map_calendar_to_typical_days(calendar::Vector{Any})
    day_mapping = []
    
    for day in calendar
        season = day["season"]
        day_type = day["day_type"]
        
        # Build typical day ID
        typical_day_id = "$(season)_$(day_type)"
        
        push!(day_mapping, typical_day_id)
    end
    
    return day_mapping
end

"""
    create_hourly_mapping(day_mapping::Vector{Any})

Create mapping from annual 8760 hours to typical day hours
"""
function create_hourly_mapping(day_mapping::Vector{Any})
    hour_mapping = []
    
    for (day_idx, typical_day_id) in enumerate(day_mapping)
        for hour in 1:24
            push!(hour_mapping, Dict(
                "typical_day_id" => typical_day_id,
                "hour_index" => hour,
                "day_index" => day_idx,
                "global_hour" => (day_idx - 1) * 24 + hour
            ))
        end
    end
    
    return hour_mapping
end

"""
    adjust_mapping_for_weights(day_mapping::Vector{String}, weights::Dict{String, Float64})

Adjust mapping to meet weight requirements
"""
function adjust_mapping_for_weights(day_mapping::Vector{Any}, weights::Dict{String, Float64})
    # Calculate occurrence count of each typical day in current mapping
    current_counts = Dict{String, Int}()
    for day_id in day_mapping
        current_counts[day_id] = get(current_counts, day_id, 0) + 1
    end
    
    # Calculate target counts
    total_days = length(day_mapping)
    target_counts = Dict{String, Int}()
    for (day_id, weight) in weights
        target_counts[day_id] = round(Int, weight)
    end
    
    # Adjust mapping
    adjusted_mapping = copy(day_mapping)
    
    
    return adjusted_mapping
end

# generate_typical_days.jl
# Generate typical day data files

using CSV
using DataFrames
using Dates
using Random

"""
    generate_typical_day_data(output_path::String)

Generate typical day data and save to CSV file
"""
function generate_typical_day_data(output_path::String)
    # Ensure directory exists
    mkpath(dirname(output_path))
    
    # List of typical day IDs
    typical_day_ids = [
        "winter_weekday", "winter_weekend", 
        "spring_weekday", "spring_weekend", 
        "summer_weekday", "summer_weekend", 
        "autumn_weekday", "autumn_weekend"
    ]
    
    # Hours per day
    hours_per_day = 24
    

    
    # Initialize dataframe with all demand types
    df = DataFrame(
        typical_day_id = String[],
        hour = Int[],
        electricity_industry_load = Float64[],
        electricity_buildings_load = Float64[],
        thermal_industry_load = Float64[],
        thermal_buildings_load = Float64[],
        transportation_demand = Float64[],
        hydrogen_industry_demand = Float64[],
        fuel_industry_demand = Float64[],
        solar_potential = Float64[],
        wind_potential = Float64[],
        electricity_price = Float64[],
        carbon_intensity = Float64[]
    )
    
    # Generate data for each typical day
    for typical_day_id in typical_day_ids
        season = split(typical_day_id, "_")[1]
        day_type = split(typical_day_id, "_")[2]
        
        # Set base parameters based on season and day type
        seasonal_factors = Dict(
            "winter" => Dict("thermal_factor" => 1.5, "solar_factor" => 0.3, "wind_factor" => 1.2, "carbon_factor" => 0.6),
            "spring" => Dict("thermal_factor" => 0.8, "solar_factor" => 0.7, "wind_factor" => 1.0, "carbon_factor" => 0.45),
            "summer" => Dict("thermal_factor" => 0.4, "solar_factor" => 1.0, "wind_factor" => 0.7, "carbon_factor" => 0.3),
            "autumn" => Dict("thermal_factor" => 1.0, "solar_factor" => 0.6, "wind_factor" => 1.1, "carbon_factor" => 0.5)
        )
        
        weekday_factors = Dict(
            "weekday" => Dict("load_factor" => 1.0, "transport_factor" => 1.0, "price_factor" => 1.2),
            "weekend" => Dict("load_factor" => 0.8, "transport_factor" => 0.6, "price_factor" => 0.9)
        )
        
        # Get factors for this typical day
        s_factors = seasonal_factors[season]
        d_factors = weekday_factors[day_type]
        
        # Generate hourly data
        Random.seed!(hash(typical_day_id))  # Ensure reproducibility
        
        
         for hour in 1:hours_per_day
            
            # Hour patterns matching parameters.jl
            # Industry electricity - relatively flat with slight daytime increase
            industry_elec_pattern = 0.85 + 0.15 * max(0, sin((hour - 6) * π / 12))
            elec_industry = 500.0 * industry_elec_pattern * d_factors["load_factor"] * (1 + 0.05 * randn())
            
            # Buildings electricity - follows occupancy patterns
            buildings_elec_base = [0.60, 0.55, 0.50, 0.45, 0.45, 0.50, 0.60, 0.75, 0.90, 0.95, 
                                  1.00, 1.00, 0.95, 0.95, 0.90, 0.90, 0.85, 0.80, 0.80, 0.75, 
                                  0.75, 0.70, 0.65, 0.60]
            elec_buildings = 200.0 * buildings_elec_base[hour] * d_factors["load_factor"] * (1 + 0.1 * randn())
            
            # Thermal demands with seasonal variation
            thermal_industry_pattern = 0.80 + 0.20 * max(0, sin((hour - 8) * π / 10))
            thermal_industry = 300.0 * thermal_industry_pattern * s_factors["thermal_factor"] * d_factors["load_factor"] * (1 + 0.1 * randn())
            
            thermal_buildings_base = [0.65, 0.60, 0.55, 0.50, 0.55, 0.65, 0.75, 0.85, 0.90, 0.85, 
                                     0.80, 0.75, 0.70, 0.70, 0.75, 0.80, 0.85, 0.95, 1.00, 0.95, 
                                     0.90, 0.85, 0.75, 0.70]
            thermal_buildings = 250.0 * thermal_buildings_base[hour] * s_factors["thermal_factor"] * d_factors["load_factor"] * (1 + 0.1 * randn())
            
            # Transportation demand (higher during commuting hours)
            transport_base = [0.30, 0.20, 0.15, 0.10, 0.15, 0.40, 0.70, 1.00, 0.90, 0.70, 
                             0.60, 0.65, 0.70, 0.65, 0.60, 0.70, 0.90, 1.00, 0.80, 0.60, 
                             0.50, 0.45, 0.40, 0.35]
            transport_demand = 1000.0 * transport_base[hour] * d_factors["transport_factor"] * (1 + 0.1 * randn())
            
            # Hydrogen industry demand (relatively constant with small variations)
            hydrogen_industry = 50.0 * (0.9 + 0.2 * rand())
            
            # Fuel industry demand (relatively constant with small variations)
            fuel_industry = 100.0 * (0.9 + 0.2 * rand())
            
            # Solar potential (zero at night, peak at noon)
            solar_factor = max(0, sin((hour - 5) * π / 14))
            solar_potential = solar_factor * s_factors["solar_factor"] * (1 + 0.2 * rand())
            
            # Wind potential (more variable with seasonal factors)
            wind_base = 0.6 + 0.4 * sin((hour - 2) * π / 24) + 0.3 * randn()
            wind_potential = clamp(wind_base * s_factors["wind_factor"], 0.1, 1.0)
            
            # Electricity price (higher during peak hours and weekdays)
            price_base = 0.10 + 0.15 * max(0, sin((hour - 6) * π / 12))  # Peak during day
            price = price_base * d_factors["price_factor"] * (1 + 0.1 * randn())
            
            # Carbon intensity (lower during high renewable periods, seasonal variation)
            carbon_base = s_factors["carbon_factor"] * (1.0 - 0.3 * solar_factor)
            carbon_intensity = carbon_base * (1 + 0.1 * randn())
            
            # Add to dataframe
            push!(df, (
                typical_day_id,
                hour,
                max(0, elec_industry),
                max(0, elec_buildings),
                max(0, thermal_industry),
                max(0, thermal_buildings),
                max(0, transport_demand),
                max(0, hydrogen_industry),
                max(0, fuel_industry),
                max(0, solar_potential),
                max(0, wind_potential),
                max(0.05, price),
                max(0.1, carbon_intensity)
            ))
           
        end
    end
    
    # Save to CSV file
    CSV.write(output_path, df)
    
    println("Typical day data has been generated and saved to: $output_path")
    return df
end