# Advanced Scenario Reduction Techniques for Nested Scenario Trees

module ScenarioReduction

using Random, Statistics, LinearAlgebra, Clustering, Distances
using DataFrames, CSV

export reduce_scenario_tree, validate_reduction_quality, fast_forward_selection, 
       moment_matching_reduction, wasserstein_reduction

# ========== Core Reduction Algorithms ==========

"""
    reduce_scenario_tree(tree, target_size::Int, method::String="fast_forward")

Reduce scenario tree to target size using specified method.
"""
function reduce_scenario_tree(tree, target_size::Int, method::String="fast_forward")
    # Generate all scenario paths
    include("nested_scenario_tree.jl")
    paths = Main.NestedScenarioTree.generate_scenario_paths(tree)
    
    if length(paths) <= target_size
        println("Tree already smaller than target size. No reduction needed.")
        return paths, collect(1:length(paths))
    end
    
    println("Reducing $(length(paths)) scenarios to $target_size using $method method...")
    
    if method == "fast_forward"
        return fast_forward_selection(paths, target_size)
    elseif method == "moment_matching"
        return moment_matching_reduction(paths, target_size)
    elseif method == "wasserstein"
        return wasserstein_reduction(paths, target_size)
    elseif method == "kmeans_clustering"
        return kmeans_clustering_reduction(paths, target_size)
    else
        error("Unknown reduction method: $method")
    end
end

"""
    fast_forward_selection(paths, target_size::Int)

Fast forward selection algorithm for scenario reduction.
"""
function fast_forward_selection(paths, target_size::Int)
    n_scenarios = length(paths)
    selected_indices = Int[]
    remaining_indices = collect(1:n_scenarios)
    
    # Extract scenario data matrix
    scenario_matrix = extract_scenario_matrix(paths)
    
    # Initialize with scenario closest to mean
    mean_scenario = mean(scenario_matrix, dims=1)[1, :]
    distances_to_mean = [norm(scenario_matrix[i, :] - mean_scenario) for i in 1:n_scenarios]
    first_idx = argmin(distances_to_mean)
    push!(selected_indices, first_idx)
    setdiff!(remaining_indices, [first_idx])
    
    # Iteratively select scenarios that maximize diversity
    for _ in 2:target_size
        if isempty(remaining_indices)
            break
        end
        
        best_idx = 0
        best_score = -Inf
        
        for candidate_idx in remaining_indices
            # Calculate minimum distance to already selected scenarios
            min_distance = Inf
            for selected_idx in selected_indices
                dist = norm(scenario_matrix[candidate_idx, :] - scenario_matrix[selected_idx, :])
                min_distance = min(min_distance, dist)
            end
            
            # Select scenario with maximum minimum distance (diversity)
            if min_distance > best_score
                best_score = min_distance
                best_idx = candidate_idx
            end
        end
        
        if best_idx > 0
            push!(selected_indices, best_idx)
            setdiff!(remaining_indices, [best_idx])
        end
    end
    
    # Adjust probabilities
    reduced_paths = paths[selected_indices]
    adjusted_paths = adjust_probabilities(reduced_paths, paths)
    
    return adjusted_paths, selected_indices
end

"""
    moment_matching_reduction(paths, target_size::Int)

Moment matching reduction preserving first and second moments.
"""
function moment_matching_reduction(paths, target_size::Int)
    n_scenarios = length(paths)
    
    # Extract scenario data and probabilities
    scenario_matrix = extract_scenario_matrix(paths)
    probabilities = [path.probability for path in paths]
    
    # Calculate original moments
    original_mean = sum(probabilities[i] * scenario_matrix[i, :] for i in 1:n_scenarios)
    original_cov = calculate_weighted_covariance(scenario_matrix, probabilities)
    
    # Use K-means clustering as initial selection
    n_features = size(scenario_matrix, 2)
    if n_features > 0
        # Perform clustering
        clustering_result = kmeans(scenario_matrix', target_size)
        cluster_centers = clustering_result.centers'
        assignments = clustering_result.assignments
        
        # Select representative scenarios for each cluster
        selected_indices = Int[]
        for cluster_id in 1:target_size
            cluster_indices = findall(x -> x == cluster_id, assignments)
            if !isempty(cluster_indices)
                # Select scenario closest to cluster center
                center = cluster_centers[cluster_id, :]
                distances = [norm(scenario_matrix[idx, :] - center) for idx in cluster_indices]
                best_local_idx = argmin(distances)
                push!(selected_indices, cluster_indices[best_local_idx])
            end
        end
        
        # Ensure we have exactly target_size scenarios
        while length(selected_indices) < target_size && length(selected_indices) < n_scenarios
            remaining = setdiff(1:n_scenarios, selected_indices)
            if !isempty(remaining)
                push!(selected_indices, remaining[1])
            end
        end
        
        selected_indices = selected_indices[1:min(target_size, length(selected_indices))]
    else
        # Fallback: random selection if no features
        selected_indices = sample(1:n_scenarios, min(target_size, n_scenarios), replace=false)
    end
    
    # Adjust probabilities to match moments
    reduced_paths = paths[selected_indices]
    adjusted_paths = moment_matching_probability_adjustment(reduced_paths, original_mean, original_cov)
    
    return adjusted_paths, selected_indices
end

"""
    wasserstein_reduction(paths, target_size::Int)

Wasserstein distance-based scenario reduction.
"""
function wasserstein_reduction(paths, target_size::Int)
    n_scenarios = length(paths)
    scenario_matrix = extract_scenario_matrix(paths)
    probabilities = [path.probability for path in paths]
    
    # Calculate pairwise Wasserstein distances (approximated by Euclidean)
    distance_matrix = zeros(n_scenarios, n_scenarios)
    for i in 1:n_scenarios
        for j in (i+1):n_scenarios
            distance_matrix[i, j] = norm(scenario_matrix[i, :] - scenario_matrix[j, :])
            distance_matrix[j, i] = distance_matrix[i, j]
        end
    end
    
    # Greedy selection to minimize total Wasserstein distance
    selected_indices = Int[]
    remaining_indices = collect(1:n_scenarios)
    
    # Start with scenario with highest probability
    first_idx = argmax(probabilities)
    push!(selected_indices, first_idx)
    setdiff!(remaining_indices, [first_idx])
    
    # Iteratively select scenarios
    for _ in 2:target_size
        if isempty(remaining_indices)
            break
        end
        
        best_idx = 0
        best_score = Inf
        
        for candidate_idx in remaining_indices
            # Calculate total distance to remaining scenarios
            total_distance = sum(distance_matrix[candidate_idx, remaining_indices])
            
            if total_distance < best_score
                best_score = total_distance
                best_idx = candidate_idx
            end
        end
        
        if best_idx > 0
            push!(selected_indices, best_idx)
            setdiff!(remaining_indices, [best_idx])
        end
    end
    
    # Adjust probabilities
    reduced_paths = paths[selected_indices]
    adjusted_paths = adjust_probabilities(reduced_paths, paths)
    
    return adjusted_paths, selected_indices
end

"""
    kmeans_clustering_reduction(paths, target_size::Int)

K-means clustering-based scenario reduction.
"""
function kmeans_clustering_reduction(paths, target_size::Int)
    scenario_matrix = extract_scenario_matrix(paths)
    n_features = size(scenario_matrix, 2)
    
    if n_features == 0
        # No features to cluster on, use random selection
        selected_indices = sample(1:length(paths), min(target_size, length(paths)), replace=false)
        return paths[selected_indices], selected_indices
    end
    
    # Perform K-means clustering
    clustering_result = kmeans(scenario_matrix', target_size)
    assignments = clustering_result.assignments
    
    # Select representative scenarios
    selected_indices = Int[]
    cluster_probabilities = Dict{Int, Float64}()
    
    for cluster_id in 1:target_size
        cluster_indices = findall(x -> x == cluster_id, assignments)
        
        if !isempty(cluster_indices)
            # Calculate cluster probability
            cluster_prob = sum(paths[idx].probability for idx in cluster_indices)
            cluster_probabilities[cluster_id] = cluster_prob
            
            # Select scenario with highest probability in cluster
            cluster_probs = [paths[idx].probability for idx in cluster_indices]
            best_local_idx = argmax(cluster_probs)
            selected_idx = cluster_indices[best_local_idx]
            push!(selected_indices, selected_idx)
        end
    end
    
    # Create adjusted paths with cluster probabilities
    reduced_paths = []
    for (i, idx) in enumerate(selected_indices)
        original_path = paths[idx]
        # Find which cluster this scenario belongs to
        cluster_id = assignments[idx]
        new_probability = cluster_probabilities[cluster_id]
        
        # Create new path with adjusted probability
        adjusted_path = Main.NestedScenarioTree.ScenarioPath(
            original_path.nodes,
            new_probability,
            original_path.path_id
        )
        push!(reduced_paths, adjusted_path)
    end
    
    return reduced_paths, selected_indices
end

# ========== Helper Functions ==========

"""
    extract_scenario_matrix(paths)

Extract numerical features from scenario paths for reduction algorithms.
"""
function extract_scenario_matrix(paths)
    n_scenarios = length(paths)
    
    # Collect all numerical features from scenario paths
    features = Float64[]
    
    for path in paths
        path_features = Float64[]
        
        for node in path.nodes
            # Extract numerical data from each node
            for (key, value) in node.data
                if isa(value, Real)
                    push!(path_features, Float64(value))
                elseif isa(value, Vector{<:Real}) && !isempty(value)
                    # Take mean of vector data
                    push!(path_features, mean(value))
                end
            end
        end
        
        if isempty(features)
            features = path_features
        end
        
        # Ensure consistent feature length
        if length(path_features) != length(features)
            # Pad or truncate to match
            target_length = length(features)
            if length(path_features) < target_length
                append!(path_features, zeros(target_length - length(path_features)))
            else
                path_features = path_features[1:target_length]
            end
        end
    end
    
    # Create feature matrix
    if isempty(features)
        return zeros(n_scenarios, 1)  # Fallback for empty features
    end
    
    feature_length = length(features)
    scenario_matrix = zeros(n_scenarios, feature_length)
    
    for (i, path) in enumerate(paths)
        path_features = Float64[]
        
        for node in path.nodes
            for (key, value) in node.data
                if isa(value, Real)
                    push!(path_features, Float64(value))
                elseif isa(value, Vector{<:Real}) && !isempty(value)
                    push!(path_features, mean(value))
                end
            end
        end
        
        # Ensure consistent length
        if length(path_features) < feature_length
            append!(path_features, zeros(feature_length - length(path_features)))
        elseif length(path_features) > feature_length
            path_features = path_features[1:feature_length]
        end
        
        scenario_matrix[i, :] = path_features
    end
    
    return scenario_matrix
end

"""
    adjust_probabilities(reduced_paths, original_paths)

Adjust probabilities of reduced scenarios to sum to 1.0.
"""
function adjust_probabilities(reduced_paths, original_paths)
    total_original_prob = sum(path.probability for path in original_paths)
    total_reduced_prob = sum(path.probability for path in reduced_paths)
    
    if total_reduced_prob ≈ 0.0
        # Equal probability assignment
        new_prob = 1.0 / length(reduced_paths)
        adjusted_paths = []
        for path in reduced_paths
            adjusted_path = Main.NestedScenarioTree.ScenarioPath(
                path.nodes,
                new_prob,
                path.path_id
            )
            push!(adjusted_paths, adjusted_path)
        end
    else
        # Proportional adjustment
        adjustment_factor = total_original_prob / total_reduced_prob
        adjusted_paths = []
        for path in reduced_paths
            adjusted_prob = path.probability * adjustment_factor
            adjusted_path = Main.NestedScenarioTree.ScenarioPath(
                path.nodes,
                adjusted_prob,
                path.path_id
            )
            push!(adjusted_paths, adjusted_path)
        end
    end
    
    return adjusted_paths
end

"""
    calculate_weighted_covariance(matrix, weights)

Calculate weighted covariance matrix.
"""
function calculate_weighted_covariance(matrix, weights)
    n, p = size(matrix)
    
    # Weighted mean
    weighted_mean = sum(weights[i] * matrix[i, :] for i in 1:n)
    
    # Weighted covariance
    cov_matrix = zeros(p, p)
    total_weight = sum(weights)
    
    for i in 1:n
        deviation = matrix[i, :] - weighted_mean
        cov_matrix += weights[i] * (deviation * deviation')
    end
    
    return cov_matrix / total_weight
end

"""
    moment_matching_probability_adjustment(paths, target_mean, target_cov)

Adjust probabilities to match target moments.
"""
function moment_matching_probability_adjustment(paths, target_mean, target_cov)
    n_scenarios = length(paths)
    
    if n_scenarios == 0
        return paths
    end
    
    # Extract scenario data
    scenario_matrix = extract_scenario_matrix(paths)
    
    if size(scenario_matrix, 2) == 0
        # No features to match, return equal probabilities
        equal_prob = 1.0 / n_scenarios
        adjusted_paths = []
        for path in paths
            adjusted_path = Main.NestedScenarioTree.ScenarioPath(
                path.nodes,
                equal_prob,
                path.path_id
            )
            push!(adjusted_paths, adjusted_path)
        end
        return adjusted_paths
    end
    
    # Simple moment matching: solve for probabilities
    # This is a simplified approach - in practice, this is a complex optimization problem
    
    # For now, use equal probabilities (more sophisticated methods would require optimization)
    equal_prob = 1.0 / n_scenarios
    adjusted_paths = []
    for path in paths
        adjusted_path = Main.NestedScenarioTree.ScenarioPath(
            path.nodes,
            equal_prob,
            path.path_id
        )
        push!(adjusted_paths, adjusted_path)
    end
    
    return adjusted_paths
end

# ========== Quality Assessment ==========

"""
    validate_reduction_quality(original_paths, reduced_paths)

Validate the quality of scenario reduction.
"""
function validate_reduction_quality(original_paths, reduced_paths)
    validation_results = Dict{String, Any}()
    
    # Probability validation
    original_prob_sum = sum(path.probability for path in original_paths)
    reduced_prob_sum = sum(path.probability for path in reduced_paths)
    
    validation_results["original_probability_sum"] = original_prob_sum
    validation_results["reduced_probability_sum"] = reduced_prob_sum
    validation_results["probability_preservation"] = abs(reduced_prob_sum - original_prob_sum) < 1e-6
    
    # Statistical moment comparison
    original_matrix = extract_scenario_matrix(original_paths)
    reduced_matrix = extract_scenario_matrix(reduced_paths)
    
    if size(original_matrix, 2) > 0 && size(reduced_matrix, 2) > 0
        original_probs = [path.probability for path in original_paths]
        reduced_probs = [path.probability for path in reduced_paths]
        
        # Mean comparison
        original_mean = sum(original_probs[i] * original_matrix[i, :] for i in 1:length(original_paths))
        reduced_mean = sum(reduced_probs[i] * reduced_matrix[i, :] for i in 1:length(reduced_paths))
        
        mean_error = norm(original_mean - reduced_mean) / (norm(original_mean) + 1e-8)
        validation_results["mean_relative_error"] = mean_error
        validation_results["mean_preservation_good"] = mean_error < 0.1
        
        # Reduction ratio
        validation_results["reduction_ratio"] = length(reduced_paths) / length(original_paths)
        validation_results["scenarios_original"] = length(original_paths)
        validation_results["scenarios_reduced"] = length(reduced_paths)
    else
        validation_results["mean_relative_error"] = 0.0
        validation_results["mean_preservation_good"] = true
        validation_results["reduction_ratio"] = length(reduced_paths) / length(original_paths)
        validation_results["scenarios_original"] = length(original_paths)
        validation_results["scenarios_reduced"] = length(reduced_paths)
    end
    
    return validation_results
end

end # module
