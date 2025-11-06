# storage_connection.jl
# 储能状态连接模块

"""
    connect_storage_states(typical_days_results::Dict, day_mapping::Vector{Any})

连接不同典型天之间的储能状态
"""
function connect_storage_states(typical_days_results::Dict, day_mapping::Vector{Any})
    connected_results = deepcopy(typical_days_results)
    
    # 初始化储能状态
    soc_elec = connected_results[day_mapping[1]]["E_storage"][1]
    soc_heat = connected_results[day_mapping[1]]["Q_storage"][1]
    soc_h2 = connected_results[day_mapping[1]]["H_storage"][1]
    
    # 按日历顺序更新储能状态
    for day in 1:length(day_mapping)
        typical_day_id = day_mapping[day]
        
        # 更新当天起始储能状态
        if day > 1
            connected_results[typical_day_id]["E_storage"][1] = soc_elec
            connected_results[typical_day_id]["Q_storage"][1] = soc_heat
            connected_results[typical_day_id]["H_storage"][1] = soc_h2
        end
        
        # 获取当天结束时的储能状态
        T = length(connected_results[typical_day_id]["P_grid"])
        soc_elec = connected_results[typical_day_id]["E_storage"][T+1]
        soc_heat = connected_results[typical_day_id]["Q_storage"][T+1]
        soc_h2 = connected_results[typical_day_id]["H_storage"][T+1]
    end
    
    return connected_results
end

"""
    resolve_with_fixed_initial_state(model_params::Dict, initial_states::Dict)

使用固定的初始储能状态重新求解模型
"""
function resolve_with_fixed_initial_state(model_params::Dict, initial_states::Dict)
    # 更新模型参数中的初始储能状态
    updated_params = deepcopy(model_params)
    updated_params["E_storage_0"] = initial_states["E_storage"]
    updated_params["Q_storage_0"] = initial_states["Q_storage"]
    updated_params["H_storage_0"] = initial_states["H_storage"]
    
    # 创建并求解模型
    model = create_low_carbon_energy_system_model(updated_params)
    
    # 求解模型
    results = solve_model(model)
    
    return results
end

# yearly_reconstruction.jl
# 全年结果重构模块

"""
    reconstruct_yearly_results(typical_days_results::Dict, hour_mapping::Vector{Any})

将典型天结果扩展到全年8760小时
"""
function reconstruct_yearly_results(typical_days_results::Dict, hour_mapping::Vector{Any})
    # 初始化全年结果
    yearly_results = Dict()
    
    # 获取所有需要扩展的结果键
    result_keys = collect(keys(collect(values(typical_days_results))[1]))
    
    # 初始化结果变量
    for key in result_keys
        if typeof(typical_days_results[hour_mapping[1]["typical_day_id"]][key]) <: Vector
            yearly_results[key] = zeros(length(hour_mapping))
        end
    end
    
    # 填充全年结果
    for (hour, mapping) in enumerate(hour_mapping)
        typical_day_id = mapping["typical_day_id"]
        hour_index = mapping["hour_index"]
        
        for key in keys(yearly_results)
            if length(typical_days_results[typical_day_id][key]) >= hour_index
                yearly_results[key][hour] = typical_days_results[typical_day_id][key][hour_index]
            end
        end
    end
    
    # 特殊处理储能状态
    storage_keys = ["E_storage", "Q_storage", "H_storage", "SOC_EV", "SOC_HV", "SOC_ICV"]
    for key in storage_keys
        if haskey(yearly_results, key)
            # 为储能状态添加最后一个时间点
            push!(yearly_results[key], yearly_results[key][end])
        end
    end
    
    return yearly_results
end

"""
    apply_seasonal_adjustments!(yearly_results::Dict, hour_mapping::Vector{Any})

应用季节性调整到全年结果
"""
function apply_seasonal_adjustments!(yearly_results::Dict, hour_mapping::Vector{Any})
    # 获取每个小时对应的季节
    seasons = [split(mapping["typical_day_id"], "_")[1] for mapping in hour_mapping]
    
    # 季节性调整系数
    seasonal_factors = Dict(
        "winter" => Dict("P_buildings_elec" => 1.1, "Q_buildings_th" => 1.3),
        "spring" => Dict("P_buildings_elec" => 1.0, "Q_buildings_th" => 1.0),
        "summer" => Dict("P_buildings_elec" => 1.2, "Q_buildings_th" => 0.7),
        "autumn" => Dict("P_buildings_elec" => 1.0, "Q_buildings_th" => 1.0)
    )
    
    # 应用调整
    for (hour, season) in enumerate(seasons)
        for (key, factor) in seasonal_factors[season]
            if haskey(yearly_results, key)
                yearly_results[key][hour] *= factor
            end
        end
    end
    
    return yearly_results
end


"""
    calculate_yearly_metrics(yearly_results::Dict, typical_days_results::Dict, weights::Dict{String, Float64})

计算全年性能指标
"""
function calculate_yearly_metrics(yearly_results::Dict, typical_days_results::Dict, weights::Dict{String, Float64})
    metrics = Dict()
    
    # 基于典型天的分析结果计算全年指标
    total_days = sum(values(weights))
    
    # 初始化累加变量
    total_grid = 0.0
    total_solar = 0.0
    total_wind = 0.0
    total_CHP = 0.0
    total_fuelcell = 0.0
    total_emissions = 0.0
    total_cost = 0.0
    total_grid_cost = 0.0
    total_fuel_cost = 0.0
    total_cert_cost = 0.0
    total_carbon_penalty = 0.0
    weighted_system_efficiency = 0.0
    total_ICV = 0.0
    total_EV = 0.0
    total_HV = 0.0
    total_ICV_energy = 0.0
    total_EV_energy = 0.0
    total_HV_energy = 0.0
    
    # 累加各典型天的加权指标
    for (typical_day_id, weight) in weights
        if haskey(typical_days_results, typical_day_id) && 
           haskey(typical_days_results[typical_day_id], "analysis")
            
            analysis = typical_days_results[typical_day_id]["analysis"]
            
            # 加权累加各指标
            total_grid += analysis["total_grid"] * weight
            total_solar += analysis["total_solar"] * weight
            total_wind += analysis["total_wind"] * weight
            total_CHP += analysis["total_CHP"] * weight
            total_fuelcell += analysis["total_fuelcell"] * weight
            total_emissions += analysis["total_emissions"] * weight
            total_cost += analysis["total_cost"] * weight
            total_grid_cost += analysis["grid_cost"] * weight
            total_fuel_cost += analysis["fuel_cost"] * weight
            
            if haskey(analysis, "cert_cost")
                total_cert_cost += analysis["cert_cost"] * weight
            end
            
            if haskey(analysis, "carbon_penalty")
                total_carbon_penalty += analysis["carbon_penalty"] * weight
            end
            
            weighted_system_efficiency += analysis["system_efficiency"] * weight
            total_ICV += analysis["total_ICV"] * weight
            total_EV += analysis["total_EV"] * weight
            total_HV += analysis["total_HV"] * weight
            total_ICV_energy += analysis["total_ICV_energy"] * weight
            total_EV_energy += analysis["total_EV_energy"] * weight
            total_HV_energy += analysis["total_HV_energy"] * weight
        end
    end
    
    # 计算全年指标
    metrics["total_grid"] = total_grid
    metrics["total_solar"] = total_solar
    metrics["total_wind"] = total_wind
    metrics["total_CHP"] = total_CHP
    metrics["total_fuelcell"] = total_fuelcell
    metrics["total_emissions"] = total_emissions
    metrics["total_cost"] = total_cost
    metrics["grid_cost"] = total_grid_cost
    metrics["fuel_cost"] = total_fuel_cost
    metrics["cert_cost"] = total_cert_cost
    metrics["carbon_penalty"] = total_carbon_penalty
    
    # 计算可再生能源占比
    total_electricity = total_grid + total_solar + total_wind + total_CHP + total_fuelcell
    if total_electricity > 0
        metrics["renewable_share"] = (total_solar + total_wind) / total_electricity
    else
        metrics["renewable_share"] = 0.0
    end
    
    # 计算系统效率（作为加权平均）
    metrics["system_efficiency"] = weighted_system_efficiency / total_days
    
    # 计算交通模式份额
    total_transport = total_ICV + total_EV + total_HV
    if total_transport > 0
        metrics["icv_share"] = total_ICV / total_transport
        metrics["ev_share"] = total_EV / total_transport
        metrics["hv_share"] = total_HV / total_transport
    end
    
    # 交通能源消耗
    metrics["total_ICV"] = total_ICV
    metrics["total_EV"] = total_EV
    metrics["total_HV"] = total_HV
    metrics["total_ICV_energy"] = total_ICV_energy
    metrics["total_EV_energy"] = total_EV_energy
    metrics["total_HV_energy"] = total_HV_energy
    
    return metrics
end

"""
    calculate_monthly_metrics(yearly_results::Dict, typical_days_results::Dict, hour_mapping::Vector{Any}, weights::Dict{String, Float64})

计算月度性能指标
"""
function calculate_monthly_metrics(yearly_results::Dict, typical_days_results::Dict, hour_mapping::Vector{Any}, weights::Dict{String, Float64})
    # 从小时映射中提取月份信息
    months = []
    for mapping in hour_mapping
        if haskey(mapping, "day_index")
            # 假设从1月1日开始
            day_of_year = mapping["day_index"]
            # 简单估算月份（不考虑闰年）
            month_approx = ceil(Int, day_of_year / 30.5)
            # 确保月份在1-12范围内
            month_val = max(1, min(12, month_approx))
            push!(months, month_val)
        else
            # 如果没有day_index，则从typical_day_id中提取季节信息
            season = split(mapping["typical_day_id"], "_")[1]
            # 将季节映射到月份中值
            season_to_month = Dict(
                "winter" => 1,  # 1月作为冬季代表
                "spring" => 4,  # 4月作为春季代表
                "summer" => 7,  # 7月作为夏季代表
                "autumn" => 10  # 10月作为秋季代表
            )
            push!(months, season_to_month[season])
        end
    end
    
    # 确保months长度与hour_mapping一致
    if length(months) != length(hour_mapping)
        # 使用更简单的方法：全年8760小时均匀分配到12个月
        hours_per_month = [744, 672, 744, 720, 744, 720, 744, 744, 720, 744, 720, 744]  # 各月小时数
        months = []
        hour_count = 0
        for month in 1:12
            for _ in 1:hours_per_month[month]
                hour_count += 1
                if hour_count <= length(hour_mapping)
                    push!(months, month)
                end
            end
        end
    end
    
    # 初始化月度指标
    monthly_metrics = Dict{Int, Dict{String, Float64}}()
    for m in 1:12
        monthly_metrics[m] = Dict{String, Float64}()
    end
    
    # 为每个月计算典型天的统计值
    monthly_days = Dict{Int, Dict{String, Float64}}()
    for m in 1:12
        monthly_days[m] = Dict{String, Float64}()
        for typical_day_id in keys(weights)
            monthly_days[m][typical_day_id] = 0.0
        end
    end
    
    # 计算每个月包含的典型天数量
    for (h, month) in enumerate(months)
        hour_index = h % 24
        if hour_index == 0
            hour_index = 24
        end
        
        if hour_index == 1  # 每天的第一个小时
            day_mapping = hour_mapping[h]
            typical_day_id = day_mapping["typical_day_id"]
            monthly_days[month][typical_day_id] += 1.0
        end
    end
    
    # 针对每个月计算指标
    for month in 1:12
        # 初始化该月累加变量
        month_total_grid = 0.0
        month_total_solar = 0.0
        month_total_wind = 0.0
        month_total_emissions = 0.0
        month_total_cost = 0.0
        month_weighted_system_efficiency = 0.0
        month_total_days = 0.0
        month_total_ICV = 0.0
        month_total_EV = 0.0
        month_total_HV = 0.0
        
        # 累加该月每种典型天的贡献
        for (typical_day_id, days) in monthly_days[month]
            if days > 0 && haskey(typical_days_results, typical_day_id) && 
               haskey(typical_days_results[typical_day_id], "analysis")
                
                analysis = typical_days_results[typical_day_id]["analysis"]
                
                # 加权累加各指标
                month_total_grid += analysis["total_grid"] * days
                month_total_solar += analysis["total_solar"] * days
                month_total_wind += analysis["total_wind"] * days
                month_total_emissions += analysis["total_emissions"] * days
                month_total_cost += analysis["total_cost"] * days
                month_weighted_system_efficiency += analysis["system_efficiency"] * days
                month_total_ICV += analysis["total_ICV"] * days
                month_total_EV += analysis["total_EV"] * days
                month_total_HV += analysis["total_HV"] * days
                
                month_total_days += days
            end
        end
        
        # 保存该月指标
        monthly_metrics[month]["total_grid"] = month_total_grid
        monthly_metrics[month]["total_solar"] = month_total_solar
        monthly_metrics[month]["total_wind"] = month_total_wind
        monthly_metrics[month]["total_emissions"] = month_total_emissions
        monthly_metrics[month]["total_cost"] = month_total_cost
        
        # 计算该月可再生能源占比
        month_total_electricity = month_total_grid + month_total_solar + month_total_wind
        if month_total_electricity > 0
            monthly_metrics[month]["renewable_share"] = (month_total_solar + month_total_wind) / month_total_electricity
        else
            monthly_metrics[month]["renewable_share"] = 0.0
        end
        
        # 计算该月系统效率
        if month_total_days > 0
            monthly_metrics[month]["system_efficiency"] = month_weighted_system_efficiency / month_total_days
        else
            monthly_metrics[month]["system_efficiency"] = 0.0
        end
        
        # 计算该月交通能源消耗
        monthly_metrics[month]["total_ICV"] = month_total_ICV
        monthly_metrics[month]["total_EV"] = month_total_EV
        monthly_metrics[month]["total_HV"] = month_total_HV
        
        # 计算该月交通模式份额
        month_total_transport = month_total_ICV + month_total_EV + month_total_HV
        if month_total_transport > 0
            monthly_metrics[month]["icv_share"] = month_total_ICV / month_total_transport
            monthly_metrics[month]["ev_share"] = month_total_EV / month_total_transport
            monthly_metrics[month]["hv_share"] = month_total_HV / month_total_transport
        else
            monthly_metrics[month]["icv_share"] = 0.0
            monthly_metrics[month]["ev_share"] = 0.0
            monthly_metrics[month]["hv_share"] = 0.0
        end
    end
    
    return monthly_metrics
end
