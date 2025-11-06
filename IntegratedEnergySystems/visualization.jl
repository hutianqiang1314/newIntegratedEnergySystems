using Plots
using DataFrames
using CSV
using PlotlyJS  # Added for Sankey diagram

# Function to plot results
function plot_results(results, T, params)
    # Time vector
    time = 1:T
    
    # Plot electricity generation
    p1 = Plots.plot(time, [results["P_grid"], results["P_solar"], results["P_wind"], 
                          results["P_CHP"], results["P_fuelcell"], results["P_storage_discharge"], results["P_EV_V2G"]],
        label=["Grid" "Solar" "Wind" "CHP" "Fuel Cell" "Storage Discharge" "EV V2G"],
        title="Electricity Generation",
        xlabel="Time (h)",
        ylabel="Power (kW)",
        linewidth=2
    )
    
    # Plot renewable potential vs. actual
    p2 = Plots.plot(time, [results["P_solar"], results["P_wind"], 
                          params["P_solar_max"], params["P_wind_max"]],
        label=["Solar Actual" "Wind Actual" "Solar Potential" "Wind Potential"],
        title="Renewable Energy Utilization",
        xlabel="Time (h)",
        ylabel="Power (kW)",
        linewidth=2
    )
    
    # Plot storage levels
    p3 = Plots.plot(1:(T+1), [results["E_storage"][1:(T+1)], results["Q_storage"][1:(T+1)], 
                            results["H_storage"][1:(T+1)]],
        label=["Electricity" "Thermal" "Hydrogen"],
        title="Storage Levels",
        xlabel="Time (h)",
        ylabel="Energy (kWh/kg)",
        linewidth=2
    )
    
    # Plot transportation demand
    p4 = Plots.plot(time, [results["D_ICV"], results["D_EV"], results["D_HV"]],
        label=["ICV" "EV" "HV"],
        title="Transportation Demand",
        xlabel="Time (h)",
        ylabel="Demand (km)",
        linewidth=2
    )
    
    # Plot vehicle state of charge
    p5 = Plots.plot(1:(T+1), [results["SOC_ICV"][1:(T+1)], results["SOC_EV"][1:(T+1)], 
                            results["SOC_HV"][1:(T+1)]],
        label=["ICV" "EV" "HV"],
        title="Vehicle State of Charge",
        xlabel="Time (h)",
        ylabel="Energy (kWh)",
        linewidth=2
    )
    
    # Plot vehicle charging/refueling
    p6 = Plots.plot(time, [results["F_ICV_refuel"], results["P_EV_charge"], 
                          results["H_HV_refuel"]],
        label=["ICV Refueling" "EV Charging" "HV Refueling"],
        title="Vehicle Energy Replenishment",
        xlabel="Time (h)",
        ylabel="Power/Fuel (kW/kg)",
        linewidth=2
    )
    
    # Plot V2G operations
    p7 = Plots.plot(time, [results["P_EV_charge"], -results["P_EV_V2G"], 
                          results["SOC_EV"][1:T]],
        label=["EV Charging" "V2G Discharging" "EV SOC"],
        title="Vehicle-to-Grid Operations",
        xlabel="Time (h)",
        ylabel="Power (kW) / SOC (kWh)",
        linewidth=2
    )
    
    # Plot hydrogen operations
    p8 = Plots.plot(time, [results["H_electrolysis"], results["H_fuelcell"], 
                          results["H_industry"], results["H_HV_refuel"]],
        label=["Electrolysis" "Fuel Cell" "Industry" "HV Refueling"],
        title="Hydrogen Operations",
        xlabel="Time (h)",
        ylabel="Hydrogen (kg/h)",
        linewidth=2
    )
    
    # Plot heat operations
    p9 = Plots.plot(time, [results["Q_CHP"], results["Q_HP"], 
                          results["Q_industry_th"], results["Q_buildings_th"]],
        label=["CHP" "Heat Pump" "Industry" "Buildings"],
        title="Heat Operations",
        xlabel="Time (h)",
        ylabel="Heat (kW)",
        linewidth=2
    )
    
    # Plot carbon emissions
    if haskey(results, "Emissions_total")
        p10 = Plots.plot(time, [results["Emissions_total"], results["CO2_captured"]],
            label=["Emissions" "Carbon Captured"],
            title="Carbon Emissions",
            xlabel="Time (h)",
            ylabel="CO2 (kg)",
            linewidth=2
        )
    end
    
    # Combine plots
    combined_plot = Plots.plot(p1, p2, p3, p4, p5, p6, p7, p8, p9, 
                              layout=(3,3), size=(1200, 900))
    
    # Save plots
    Plots.savefig(combined_plot, "energy_system_results.png")
    Plots.savefig(p1, "electricity_generation.png")
    Plots.savefig(p2, "renewable_utilization.png")
    Plots.savefig(p3, "storage_levels.png")
    Plots.savefig(p4, "transportation_demand.png")
    Plots.savefig(p5, "vehicle_soc.png")
    Plots.savefig(p6, "vehicle_refueling.png")
    Plots.savefig(p7, "v2g_operations.png")
    Plots.savefig(p8, "hydrogen_operations.png")
    Plots.savefig(p9, "heat_operations.png")
    
    if haskey(results, "Emissions_total")
        Plots.savefig(p10, "carbon_emissions.png")
    end
    
    return combined_plot
end

# Function to create a Sankey diagram of energy flows
function create_energy_sankey(results, T, params)
    # Calculate energy flows using the EXACT SAME calculations as in model constraints
    
    # Electricity flows - EXACT SAME AS MODEL
    electricity_supply = zeros(T)
    electricity_demand = zeros(T)
    
    for t in 1:T
        # Supply calculation exactly as in electricity_balance constraint
        electricity_supply[t] = results["P_grid"][t] + results["P_solar"][t] + results["P_wind"][t] + 
                               results["P_CHP"][t] + results["P_fuelcell"][t] + 
                               results["P_storage_discharge"][t] + results["P_EV_V2G"][t]
        
        # Demand calculation exactly as in electricity_balance constraint
        electricity_demand[t] = results["P_industry_elec"][t] + results["P_buildings_elec"][t] + 
                               results["P_electrolysis_H2"][t] + results["P_electrolysis_fuel"][t] + 
                               results["P_HP"][t] + results["P_storage_charge"][t] + 
                               results["P_EV_charge"][t] + results["P_CCUS"][t]
    end
    
    # Heat flows - EXACT SAME AS MODEL
    heat_supply = zeros(T)
    heat_demand = zeros(T)
    
    for t in 1:T
        # Supply calculation exactly as in heat_balance constraint
        heat_supply[t] = results["Q_CHP"][t] + results["Q_HP"][t] + 
                        results["Q_storage_discharge"][t] + 
                        results["P_HP"][t] * params["eta_wasteheat"]
        
        # Demand calculation exactly as in heat_balance constraint
        heat_demand[t] = results["Q_industry_th"][t] + results["Q_buildings_th"][t] + 
                        results["Q_storage_charge"][t]
    end
    
    # Hydrogen flows - EXACT SAME AS MODEL
    hydrogen_supply = zeros(T)
    hydrogen_demand = zeros(T)
    
    for t in 1:T
        # Supply calculation exactly as in hydrogen_balance constraint
        hydrogen_supply[t] = results["H_electrolysis"][t] + results["H_storage_discharge"][t]
        
        # Demand calculation exactly as in hydrogen_balance constraint
        hydrogen_demand[t] = results["H_industry"][t] + results["H_fuelcell"][t] + 
                            results["H_storage_charge"][t] + results["H_HV_refuel"][t]
    end
    
    # Calculate total flows over the time period
    # Electricity sources
    total_grid = sum(results["P_grid"])
    total_solar = sum(results["P_solar"])
    total_wind = sum(results["P_wind"])
    total_CHP_elec = sum(results["P_CHP"])
    total_fuelcell = sum(results["P_fuelcell"])
    total_storage_discharge = sum(results["P_storage_discharge"])
    total_EV_V2G = sum(results["P_EV_V2G"])
    
    # Electricity demands - UPDATED to match model constraints
    total_industry_elec = sum(results["P_industry_elec"])
    total_buildings_elec = sum(results["P_buildings_elec"])
    total_electrolysis_H2 = sum(results["P_electrolysis_H2"])
    total_electrolysis_fuel = sum(results["P_electrolysis_fuel"])
    total_HP_elec = sum(results["P_HP"])
    total_storage_charge = sum(results["P_storage_charge"])
    total_EV_charge = sum(results["P_EV_charge"])
    total_CCUS_energy = sum(results["P_CCUS"])
    
    # Heat sources and demands
    total_CHP_heat = sum(results["Q_CHP"]) / params["eta_heatpump"]
    total_HP_heat = sum(results["Q_HP"]) / params["eta_heatpump"]
    total_heat_storage_discharge = sum(results["Q_storage_discharge"]) / params["eta_heatpump"]
    
    total_industry_heat = sum(results["Q_industry_th"]) / params["eta_heatpump"]
    total_buildings_heat = sum(results["Q_buildings_th"]) / params["eta_heatpump"]
    total_heat_storage_charge = sum(results["Q_storage_charge"])/ params["eta_heatpump"]
    
    # Hydrogen sources and demands
    total_hydrogen_electrolysis = sum(results["H_electrolysis"]) / params["eta_electrolysis"]
    total_hydrogen_storage_discharge = sum(results["H_storage_discharge"]) / params["eta_electrolysis"]
    
    total_hydrogen_industry = sum(results["H_industry"]) / params["eta_electrolysis"]
    total_hydrogen_fuelcell = sum(results["H_fuelcell"]) / params["eta_electrolysis"]
    total_hydrogen_storage_charge = sum(results["H_storage_charge"]) / params["eta_electrolysis"]
    total_hydrogen_HV = sum(results["H_HV_refuel"]) / params["eta_electrolysis"]
    
    # Fuel sources and demands
    total_fuel = sum(results["F_fuel"]) / params["eta_power_to_fuel"]
    total_fuel_from_electrolysis = sum(results["P_electrolysis_fuel"]) 
    
    total_ICV_fuel = sum(results["F_ICV_refuel"]) / params["eta_power_to_fuel"]
    total_fuel_CHP = sum(results["F_CHP"]) / params["eta_power_to_fuel"]
    total_fuel_industry = sum(results["F_industry"]) / params["eta_power_to_fuel"]
    
    # Vehicle energy calculations
    total_ICV_distance = sum(results["D_ICV"])
    total_EV_distance = sum(results["D_EV"])
    total_HV_distance = sum(results["D_HV"])
    
    total_ICV_energy = total_ICV_distance * params["alpha_ICV"] / params["eta_power_to_fuel"] 
    total_EV_energy = total_EV_distance * params["alpha_EV"] 
    total_HV_energy = total_HV_distance * params["alpha_HV"] / params["eta_electrolysis"]
    
    total_CCUS_energy = sum(results["P_CCUS"])
    # Define nodes with clear separation of supply and demand for each energy carrier
    nodes = [
        # Electricity supply sources (0-6)
        "Grid", "Solar", "Wind", "CHP_elec", "FuelCell", "BESS_discharge", "EV_V2G",
        
        # Electricity supply/demand node (7)
        "Electricity",
        
        # Electricity demand destinations (8-13)
        "Industry_elec", "Buildings_elec", "Electrolysis", "HP", "BESS_charge", "EV_charge",
        
        # Heat supply sources (14-16)
        "CHP_heat", "HP_heat", "TESS_discharge",
        
        # Heat supply/demand node (17)
        "Heat",
        
        # Heat demand destinations (18-20)
        "Industry_heat", "Buildings_heat", "TESS_charge",
        
        # Hydrogen supply sources (21-22)
        "Electrolysis_H2", "HESS_discharge",
        
        # Hydrogen supply/demand node (23)
        "Hydrogen",
        
        # Hydrogen demand destinations (24-27)
        "Industry_H2", "FuelCell_H2", "HESS_charge", "HV_refuel",
        
        # Fuel supply sources (28-30)
        "Electrolysis_fuel", "HP_waste_heat", "Fuel_source",
        
        # Fuel supply/demand node (31)
        "Fuel",
        
        # Fuel demand destinations (32-34)
        "ICV_fuel", "CHP_fuel", "Industry_fuel",
        
        # Transportation supply sources (35-37)
        "ICV_transport", "EV_transport", "HV_transport",
        
        # Transportation demand (38)
        "Transportation",

        # Fuel imported (39)
        "Fuel_imported",

        # Industy and Buildings (40-41)
        "Industry", "Buildings", 

        # Transportation (42)
        "Transportation",

        # CCUS (43)
        "CCUS"
    ]
    
    # Define links (source, target, value)
    links = []
    
    # 1. ELECTRICITY FLOWS
    # Electricity supply to Electricity node
    push!(links, Dict("source" => 0, "target" => 7, "value" => total_grid))           # Grid → Electricity
    push!(links, Dict("source" => 1, "target" => 7, "value" => total_solar))          # Solar → Electricity
    push!(links, Dict("source" => 2, "target" => 7, "value" => total_wind))           # Wind → Electricity
    push!(links, Dict("source" => 3, "target" => 7, "value" => total_CHP_elec))       # CHP_elec → Electricity
    push!(links, Dict("source" => 4, "target" => 7, "value" => total_fuelcell))       # FuelCell → Electricity
    push!(links, Dict("source" => 5, "target" => 7, "value" => total_storage_discharge)) # BESS_discharge → Electricity
    push!(links, Dict("source" => 6, "target" => 7, "value" => total_EV_V2G))         # EV_V2G → Electricity
    
    # Electricity node to Electricity demands
    push!(links, Dict("source" => 7, "target" => 8, "value" => total_industry_elec))  # Electricity → Industry_elec
    push!(links, Dict("source" => 7, "target" => 9, "value" => total_buildings_elec)) # Electricity → Buildings_elec
    push!(links, Dict("source" => 7, "target" => 10, "value" => total_electrolysis_H2))  # Electricity → Electrolysis
    push!(links, Dict("source" => 7, "target" => 11, "value" => total_HP_elec))       # Electricity → HP
    push!(links, Dict("source" => 7, "target" => 12, "value" => total_storage_charge)) # Electricity → BESS_charge
    push!(links, Dict("source" => 7, "target" => 13, "value" => total_EV_charge))     # Electricity → EV_charge
    push!(links, Dict("source" => 13, "target" => 6, "value" => total_EV_V2G))     # Electricity → EV_charge
    push!(links, Dict("source" => 7, "target" => 43, "value" => total_CCUS_energy)) # Electricity → CCUS
    # 2. HEAT FLOWS
    # Heat supply to Heat node
    push!(links, Dict("source" => 14, "target" => 17, "value" => total_CHP_heat))     # CHP_heat → Heat
    push!(links, Dict("source" => 15, "target" => 17, "value" => total_HP_heat))      # HP_heat → Heat
    push!(links, Dict("source" => 16, "target" => 17, "value" => total_heat_storage_discharge)) # TESS_discharge → Heat
    
    # Heat node to Heat demands
    push!(links, Dict("source" => 17, "target" => 18, "value" => total_industry_heat)) # Heat → Industry_heat
    push!(links, Dict("source" => 17, "target" => 19, "value" => total_buildings_heat)) # Heat → Buildings_heat
    push!(links, Dict("source" => 17, "target" => 20, "value" => total_heat_storage_charge)) # Heat → TESS_charge
    
    # 3. HYDROGEN FLOWS
    # Hydrogen supply to Hydrogen node
    push!(links, Dict("source" => 21, "target" => 23, "value" => total_hydrogen_electrolysis)) # Electrolysis_H2 → Hydrogen
    push!(links, Dict("source" => 22, "target" => 23, "value" => total_hydrogen_storage_discharge)) # HESS_discharge → Hydrogen
    
    # Hydrogen node to Hydrogen demands
    push!(links, Dict("source" => 23, "target" => 24, "value" => total_hydrogen_industry)) # Hydrogen → Industry_H2
    push!(links, Dict("source" => 23, "target" => 25, "value" => total_hydrogen_fuelcell)) # Hydrogen → FuelCell_H2
    push!(links, Dict("source" => 23, "target" => 26, "value" => total_hydrogen_storage_charge)) # Hydrogen → HESS_charge
    push!(links, Dict("source" => 23, "target" => 27, "value" => total_hydrogen_HV)) # Hydrogen → HV_refuel
    
    # 4. FUEL FLOWS
    # Fuel supply to Fuel node
    push!(links, Dict("source" => 39, "target" => 31, "value" => total_fuel))
    push!(links, Dict("source" => 28, "target" => 31, "value" => total_fuel_from_electrolysis)) # Electrolysis_fuel → Fuel
    
    # Fuel node to Fuel demands
    push!(links, Dict("source" => 31, "target" => 32, "value" => total_ICV_fuel)) # Fuel → ICV_fuel
    push!(links, Dict("source" => 31, "target" => 33, "value" => total_fuel_CHP)) # Fuel → CHP_fuel
    push!(links, Dict("source" => 31, "target" => 34, "value" => total_fuel_industry)) # Fuel → Industry_fuel
    
    # 5. TRANSPORTATION FLOWS
    # Connect vehicles to transportation
    push!(links, Dict("source" => 35, "target" => 38, "value" => total_ICV_energy)) # ICV_transport → Transportation
    push!(links, Dict("source" => 36, "target" => 38, "value" => total_EV_energy)) # EV_transport → Transportation
    push!(links, Dict("source" => 37, "target" => 38, "value" => total_HV_energy)) # HV_transport → Transportation
    
    # 6. CROSS-CARRIER CONNECTIONS
    # Connect Electrolysis to Hydrogen production
    push!(links, Dict("source" => 10, "target" => 21, "value" => total_hydrogen_electrolysis)) # Electrolysis → Electrolysis_H2
    push!(links, Dict("source" => 10, "target" => 28, "value" => total_fuel_from_electrolysis)) # Electrolysis → Electrolysis_Fuel

    # Connect HP to Heat production
    push!(links, Dict("source" => 11, "target" => 15, "value" => total_HP_heat)) # HP → HP_heat
    
    # Connect CHP to both electricity and heat
    push!(links, Dict("source" => 33, "target" => 3, "value" => total_CHP_elec)) # CHP_fuel → CHP_elec
    push!(links, Dict("source" => 33, "target" => 14, "value" => total_CHP_heat)) # CHP_fuel → CHP_heat
    
    # Connect Fuel Cell between hydrogen and electricity
    push!(links, Dict("source" => 25, "target" => 4, "value" => total_fuelcell)) # FuelCell_H2 → FuelCell
    
    # Connect vehicles to their energy sources
    push!(links, Dict("source" => 32, "target" => 35, "value" => total_ICV_energy)) # ICV_fuel → ICV_transport
    push!(links, Dict("source" => 13, "target" => 36, "value" => total_EV_energy)) # EV_charge → EV_transport
    push!(links, Dict("source" => 27, "target" => 37, "value" => total_HV_energy)) # HV_refuel → HV_transport
    
    # Connect storage systems (charge/discharge)
    push!(links, Dict("source" => 12, "target" => 5, "value" => total_storage_discharge * params["eta_elec"])) # BESS_charge → BESS_discharge
    push!(links, Dict("source" => 20, "target" => 16, "value" => total_heat_storage_discharge * params["eta_th"])) # TESS_charge → TESS_discharge
    push!(links, Dict("source" => 26, "target" => 22, "value" => total_hydrogen_storage_discharge * params["eta_hydrogen"])) # HESS_charge → HESS_discharge
    
    # # Connect industry and buildings to their respective energy sources
    push!(links, Dict("source" => 8, "target" => 40, "value" => total_industry_elec)) # Industry_elec → Industry 
    push!(links, Dict("source" => 18, "target" => 40, "value" => total_industry_heat)) # Industry_heat → Industry
    push!(links, Dict("source" => 24, "target" => 40, "value" => total_hydrogen_industry)) # Industry_hy → Buildings 
    push!(links, Dict("source" => 34, "target" => 40, "value" => total_fuel_industry)) # Industry_hy → Buildings

    push!(links, Dict("source" => 9, "target" => 41, "value" => total_buildings_elec)) # Buildings_elec → Buildings
    push!(links, Dict("source" => 19, "target" => 41, "value" => total_buildings_heat)) # Buildings_heat → Buildings

    # Filter out links with very small values to make the diagram cleaner
    # links = filter(link -> link["value"] > 0.001, links)
    
    # Create Sankey diagram
    sankey_plot = PlotlyJS.plot(
        PlotlyJS.sankey(
            node = Dict(
                :pad => 15,
                :thickness => 20,
                :line => Dict(:color => "black", :width => 0.5),
                :label => nodes,
                :color => get_node_colors(nodes)
            ),
            link = Dict(
                :source => [link["source"] for link in links],
                :target => [link["target"] for link in links],
                :value => [link["value"] for link in links],
                :color => [get_link_color(link["source"], link["target"], nodes) for link in links]
            )
        ),
        Layout(title="Low-carbon Operations of Integrated Energy Systems", font_size=10)
    )
    
    # Save the Sankey diagram
    PlotlyJS.savefig(sankey_plot, "energy_sankey.html")
    
    return sankey_plot
end

# Helper function to get node colors based on node type
function get_node_colors(nodes)
    colors = []
    
    for node in nodes
        if occursin("Grid", node) || occursin("Solar", node) || occursin("Wind", node) || 
           occursin("elec", node) || occursin("Electricity", node) || occursin("BESS", node) || 
           occursin("EV", node) && !occursin("transport", node)
            push!(colors, "rgba(0, 0, 255, 0.7)")  # Blue for electricity
        elseif occursin("heat", node) || occursin("Heat", node) || occursin("TESS", node)
            push!(colors, "rgba(255, 0, 0, 0.7)")  # Red for heat
        elseif occursin("H2", node) || occursin("Hydrogen", node) || occursin("HESS", node) || 
               occursin("HV", node) && !occursin("transport", node)
            push!(colors, "rgba(0, 128, 0, 0.7)")  # Green for hydrogen
        elseif occursin("fuel", node) || occursin("Fuel", node) || occursin("ICV", node) && !occursin("transport", node)
            push!(colors, "rgba(255, 165, 0, 0.7)")  # Orange for fuel
        elseif occursin("transport", node) || occursin("Transportation", node)
            push!(colors, "rgba(128, 0, 128, 0.7)")  # Purple for transportation
        else
            push!(colors, "rgba(128, 128, 128, 0.7)")  # Gray for others
        end
    end
    
    return colors
end

# Helper function to get link colors based on source and target nodes
function get_link_color(source_idx, target_idx, nodes)
    source = nodes[source_idx + 1]  # +1 because Julia is 1-indexed but Plotly expects 0-indexed
    target = nodes[target_idx + 1]
    
    # Electricity flows (blue)
    if (occursin("elec", source) || occursin("Electricity", source) || 
        occursin("Grid", source) || occursin("Solar", source) || occursin("Wind", source) || 
        occursin("BESS", source) || occursin("EV", source)) &&
       (occursin("elec", target) || occursin("Electricity", target) || 
        occursin("BESS", target) || occursin("EV", target))
        return "rgba(0, 0, 255, 0.4)"  # Blue with transparency
    
    # Heat flows (red)
    elseif (occursin("heat", source) || occursin("Heat", source) || occursin("TESS", source)) &&
           (occursin("heat", target) || occursin("Heat", target) || occursin("TESS", target))
        return "rgba(255, 0, 0, 0.4)"  # Red with transparency
    
    # Hydrogen flows (green)
    elseif (occursin("H2", source) || occursin("Hydrogen", source) || occursin("HESS", source) || 
            occursin("HV", source)) &&
           (occursin("H2", target) || occursin("Hydrogen", target) || occursin("HESS", target) || 
            occursin("HV", target))
        return "rgba(0, 128, 0, 0.4)"  # Green with transparency
    
    # Fuel flows (orange)
    elseif (occursin("fuel", source) || occursin("Fuel", source) || occursin("ICV", source)) &&
           (occursin("fuel", target) || occursin("Fuel", target) || occursin("ICV", target))
        return "rgba(255, 165, 0, 0.4)"  # Orange with transparency
    
    # Transportation flows (purple)
    elseif (occursin("transport", source) || occursin("Transportation", source)) &&
           (occursin("transport", target) || occursin("Transportation", target))
        return "rgba(128, 0, 128, 0.4)"  # Purple with transparency
    
    # Cross-carrier flows
    else
        return "rgba(100, 100, 100, 0.4)"  # Gray with transparency for cross-carrier connections
    end
end


# Helper function to get link colors based on source and target
function get_link_color(source, target)
    # Electricity flows (blue)
    if source in [0, 1, 2, 3, 4, 7] && target in [5, 6, 7, 10, 13, 15]
        return "rgba(0, 0, 255, 0.4)"  # Blue with transparency
    # Heat flows (red)
    elseif source in [3, 5, 8] && target in [8, 11, 14]
        return "rgba(255, 0, 0, 0.4)"  # Red with transparency
    # Hydrogen flows (green)
    elseif source in [6, 9] && target in [4, 9, 12, 17]
        return "rgba(0, 128, 0, 0.4)"  # Green with transparency
    # Fuel flows (orange)
    elseif source == 18
        return "rgba(255, 165, 0, 0.4)"  # Orange with transparency
    # Transportation flows (dark green)
    elseif target == 19
        return "rgba(0, 100, 0, 0.4)"  # Dark green with transparency
    # Default
    else
        return "rgba(200, 200, 200, 0.4)"  # Light gray with transparency
    end
end


# Function to create pie charts of energy distribution
function create_energy_pie_charts(results, T)
    # Calculate total energy from different sources
    total_grid = sum(results["P_grid"])
    total_solar = sum(results["P_solar"])
    total_wind = sum(results["P_wind"])
    total_CHP_elec = sum(results["P_CHP"])
    total_fuelcell = sum(results["P_fuelcell"])
    
    # Calculate total electricity consumption
    total_industry_elec = sum(results["P_industry_elec"])
    total_buildings_elec = sum(results["P_buildings_elec"])
    total_electrolysis = sum(results["P_electrolysis"])
    total_HP = sum(results["P_HP"])
    total_EV_charge = sum(results["P_EV_charge"])
    total_storage_charge = sum(results["P_storage_charge"])
    
    # Calculate transportation energy
    total_ICV = sum(results["D_ICV"])
    total_EV = sum(results["D_EV"])
    total_HV = sum(results["D_HV"])
    total_transport = total_ICV + total_EV + total_HV
    
    # Create pie chart for electricity sources
    electricity_sources = ["Grid", "Solar", "Wind", "CHP", "Fuel Cell"]
    electricity_values = [total_grid, total_solar, total_wind, total_CHP_elec, total_fuelcell]
    
    p1 = Plots.pie(
        electricity_sources,
        electricity_values,
        title="Electricity Sources",
        legend=:outertopright
    )
    
    # Create pie chart for electricity consumption
    electricity_consumers = ["Industry", "Buildings", "Electrolysis", "Heat Pump", "EV Charging", "Storage"]
    electricity_consumption = [total_industry_elec, total_buildings_elec, total_electrolysis, total_HP, total_EV_charge, total_storage_charge]
    
    p2 = Plots.pie(
        electricity_consumers,
        electricity_consumption,
        title="Electricity Consumption",
        legend=:outertopright
    )
    
    # Create pie chart for transportation mode split
    transport_modes = ["ICV", "EV", "HV"]
    transport_values = [total_ICV, total_EV, total_HV]
    
    p3 = Plots.pie(
        transport_modes,
        transport_values,
        title="Transportation Mode Split",
        legend=:outertopright
    )
    
    # Combine pie charts
    combined_pies = Plots.plot(p1, p2, p3, layout=(1,3), size=(1200, 400))
    
    # Save pie charts
    Plots.savefig(combined_pies, "energy_distribution_pies.png")
    
    return combined_pies
end

# Function to create time series plots for specific analysis
function create_time_series_plots(results, T, params)
    # Time vector
    time = 1:T
    
    # Plot electricity balance
    electricity_supply = [results["P_grid"][t] + results["P_solar"][t] + results["P_wind"][t] + 
                         results["P_CHP"][t] + results["P_fuelcell"][t] + 
                         results["P_storage_discharge"][t] + results["P_EV_V2G"][t] for t in 1:T]
    
    electricity_demand = [results["P_industry_elec"][t] + results["P_buildings_elec"][t] + 
                         results["P_electrolysis_H2"][t] + results["P_electrolysis_fuel"][t] + 
                         results["P_HP"][t] + results["P_storage_charge"][t] + results["P_EV_charge"][t] + results["P_CCUS"][t] for t in 1:T]
    
    p1 = Plots.plot(time, [electricity_supply, electricity_demand],
        label=["Supply" "Demand"],
        title="Electricity Balance",
        xlabel="Time (h)",
        ylabel="Power (kW)",
        linewidth=2
    )
    
    # Plot heat balance
    heat_supply = [results["Q_CHP"][t] + results["Q_HP"][t] + results["Q_storage_discharge"][t] + results["P_HP"][t] * params["eta_wasteheat"] for t in 1:T]
    heat_demand = [results["Q_industry_th"][t] + results["Q_buildings_th"][t] + results["Q_storage_charge"][t] for t in 1:T]
    
    p2 = Plots.plot(time, [heat_supply, heat_demand],
        label=["Supply" "Demand"],
        title="Heat Balance",
        xlabel="Time (h)",
        ylabel="Heat (kW)",
        linewidth=2
    )
    
    # Plot hydrogen balance
    hydrogen_supply = [results["H_electrolysis"][t] + results["H_storage_discharge"][t] for t in 1:T]
    hydrogen_demand = [results["H_industry"][t] + results["H_fuelcell"][t] + 
                      results["H_storage_charge"][t] + results["H_HV_refuel"][t] for t in 1:T]
    
    p3 = Plots.plot(time, [hydrogen_supply, hydrogen_demand],
        label=["Supply" "Demand"],
        title="Hydrogen Balance",
        xlabel="Time (h)",
        ylabel="Hydrogen (kg/h)",
        linewidth=2
    )
    
    # Plot vehicle energy dynamics
    # ICV energy dynamics
    p4 = Plots.plot(time, [results["D_ICV"] .* params["alpha_ICV"], results["F_ICV_refuel"]],
        label=["Consumption" "Refueling"],
        title="ICV Energy Dynamics",
        xlabel="Time (h)",
        ylabel="Energy (kWh)",
        linewidth=2
    )
    
    # EV energy dynamics
    p5 = Plots.plot(time, [results["D_EV"] .* params["alpha_EV"], results["P_EV_charge"] .* params["eta_EV_charge"], results["P_EV_V2G"] ./ params["eta_EV_discharge"]],
        label=["Consumption" "Charging" "V2G"],
        title="EV Energy Dynamics",
        xlabel="Time (h)",
        ylabel="Energy (kWh)",
        linewidth=2
    )
    
    # HV energy dynamics
    p6 = Plots.plot(time, [results["D_HV"] .* params["alpha_HV"], results["H_HV_refuel"]],
        label=["Consumption" "Refueling"],
        title="HV Energy Dynamics",
        xlabel="Time (h)",
        ylabel="Energy (kWh)",
        linewidth=2
    )
    
    # Combine plots
    combined_plot = Plots.plot(p1, p2, p3, p4, p5, p6, layout=(2,3), size=(1200, 800))
    
    # Save plots
    Plots.savefig(combined_plot, "energy_balance_analysis.png")
    
    return combined_plot
end

# Function to export results to CSV
function export_results_to_csv(results, T, filename="energy_system_results.csv")
    # Create a DataFrame to hold the results
    df = DataFrame()
    
    # Add time column
    df[!, :Time] = 1:T
    
    # Add all time series data
    for (key, value) in results
        # Skip non-time series data or data with different length
        if isa(value, Vector) && length(value) >= T
            df[!, Symbol(key)] = value[1:T]
        end
    end
    
    # Export to CSV
    CSV.write(filename, df)
    println("Results exported to $filename")
    
    return df
end

# Function to visualize all results
function visualize_all_results(results, T, params)
    # Generate all visualizations
    energy_plots = plot_results(results, T, params)
    sankey_diagram = create_energy_sankey(results, T, params)
    pie_charts = create_energy_pie_charts(results, T)
    time_series_plots = create_time_series_plots(results, T, params)
    
    # Export results to CSV
    export_results_to_csv(results, T)
    
    println("All visualizations created successfully.")
    
    return Dict(
        "energy_plots" => energy_plots,
        "sankey_diagram" => sankey_diagram,
        "pie_charts" => pie_charts,
        "time_series_plots" => time_series_plots
    )
end
