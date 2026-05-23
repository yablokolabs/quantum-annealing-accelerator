"""Problem generators for Ising model optimization.

Each function returns a (weights, biases) tuple ready for IsingModel.
"""

from __future__ import annotations

from typing import Optional

import numpy as np
from numpy.typing import NDArray


def max_cut(
    graph_type: str = "ring",
    num_nodes: int = 8,
    seed: Optional[int] = None,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """Generate an Ising formulation for the Max-Cut problem.

    Max-Cut: partition graph vertices into two sets to maximize
    edges crossing the partition. Maps to minimizing:
        E = -Σ_{(i,j)∈edges} w_ij (1 - σ_i σ_j) / 2
    which is equivalent to: J_ij = -w_ij (negative coupling encourages anti-alignment).

    Args:
        graph_type: One of 'ring', 'complete', 'random'.
        num_nodes: Number of graph vertices / spins.
        seed: Random seed for 'random' graph type.

    Returns:
        (weights, biases) tuple for IsingModel.
    """
    rng = np.random.default_rng(seed)
    weights = np.zeros((num_nodes, num_nodes), dtype=np.float64)

    if graph_type == "ring":
        for i in range(num_nodes):
            j = (i + 1) % num_nodes
            weights[i, j] = -1.0
            weights[j, i] = -1.0

    elif graph_type == "complete":
        for i in range(num_nodes):
            for j in range(i + 1, num_nodes):
                weights[i, j] = -1.0
                weights[j, i] = -1.0

    elif graph_type == "random":
        for i in range(num_nodes):
            for j in range(i + 1, num_nodes):
                if rng.random() > 0.5:
                    w = -rng.uniform(0.5, 2.0)
                    weights[i, j] = w
                    weights[j, i] = w

    else:
        raise ValueError(f"Unknown graph type: {graph_type}. Use 'ring', 'complete', or 'random'.")

    biases = np.zeros(num_nodes, dtype=np.float64)
    return weights, biases


def graph_partition(
    num_nodes: int = 8,
    seed: Optional[int] = None,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """Generate an Ising formulation for balanced graph bisection.

    Minimize edges cut subject to equal partition sizes.
    Uses a random graph with penalty for partition imbalance:
        E = Σ_{(i,j)∈edges} (1 - σ_i σ_j)/2 + λ(Σ_i σ_i)²

    The penalty expands to a coupling term proportional to identity
    shift on J and no net bias (the constant is dropped).

    Args:
        num_nodes: Number of nodes (should be even for balanced partition).
        seed: Random seed.

    Returns:
        (weights, biases) tuple for IsingModel.
    """
    rng = np.random.default_rng(seed)

    # Random graph adjacency
    weights = np.zeros((num_nodes, num_nodes), dtype=np.float64)
    for i in range(num_nodes):
        for j in range(i + 1, num_nodes):
            if rng.random() > 0.5:
                # Positive coupling: encourages alignment → penalizes cutting
                weights[i, j] = 1.0
                weights[j, i] = 1.0

    # Balance penalty: λ(Σ σ_i)² = λ Σ_{i,j} σ_i σ_j
    # Adds uniform coupling to all pairs
    penalty = 2.0
    for i in range(num_nodes):
        for j in range(i + 1, num_nodes):
            weights[i, j] -= penalty
            weights[j, i] -= penalty

    biases = np.zeros(num_nodes, dtype=np.float64)
    return weights, biases


def sat_approx(
    num_vars: int = 4,
    clauses: Optional[list[list[int]]] = None,
    seed: Optional[int] = None,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """Generate an Ising formulation for approximate SAT solving.

    Each clause (x_a ∨ x_b ∨ x_c) is mapped to an Ising penalty.
    Variable x_i maps to spin σ_i via: x_i = (1 + σ_i) / 2.
    Negation ¬x_i maps to (1 - σ_i) / 2.

    A 3-SAT clause (l_a ∨ l_b ∨ l_c) is unsatisfied only when all
    literals are false. The penalty for a clause is:
        P = (1 - l_a)(1 - l_b)(1 - l_c) / 8
    expanded in terms of spins.

    Args:
        num_vars: Number of Boolean variables.
        clauses: List of clauses, each clause is a list of signed integers.
                 Positive int i means variable i, negative means ¬variable |i|.
                 Variables are 1-indexed.
        seed: Random seed (used if clauses is None to generate random clauses).

    Returns:
        (weights, biases) tuple for IsingModel.
    """
    rng = np.random.default_rng(seed)

    if clauses is None:
        # Generate random 3-SAT clauses
        num_clauses = max(1, num_vars * 3)
        clauses = []
        for _ in range(num_clauses):
            vars_in_clause = rng.choice(
                np.arange(1, num_vars + 1), size=min(3, num_vars), replace=False
            )
            signs = rng.choice([-1, 1], size=len(vars_in_clause))
            clause = [int(s * v) for s, v in zip(signs, vars_in_clause)]
            clauses.append(clause)

    weights = np.zeros((num_vars, num_vars), dtype=np.float64)
    biases = np.zeros(num_vars, dtype=np.float64)

    for clause in clauses:
        # Convert each literal to spin representation
        # literal l_k: if positive (var i), spin contribution is +σ_{i-1}
        #               if negative (¬var i), spin contribution is -σ_{i-1}
        # Clause penalty: product of (1 - s_k * σ_{idx_k}) / 2 for each literal
        literals = []
        for lit in clause:
            idx = abs(lit) - 1  # 0-indexed
            sign = 1 if lit > 0 else -1
            literals.append((idx, sign))

        # For a clause with literals, penalty = Π_k (1 - s_k σ_k) / 2^n
        # Expand for pairs and singles
        n = len(literals)
        norm = 2.0 ** n

        # Constant term (ignored, doesn't affect optimization)
        # Linear terms: -s_k / norm * Π_{j≠k} 1 = -s_k / norm (at order 1)
        # For 3 literals: expand (1-a)(1-b)(1-c) = 1 - a - b - c + ab + ac + bc - abc
        # We ignore constant and cubic+ terms for Ising (quadratic model)

        for k, (idx_k, sign_k) in enumerate(literals):
            # Linear contribution
            biases[idx_k] -= sign_k / norm

        for k in range(n):
            for m in range(k + 1, n):
                idx_k, sign_k = literals[k]
                idx_m, sign_m = literals[m]
                if idx_k != idx_m:
                    weights[idx_k, idx_m] += sign_k * sign_m / norm
                    weights[idx_m, idx_k] += sign_k * sign_m / norm

    return weights, biases


def tsp_approx(
    num_cities: int = 4,
    distances: Optional[NDArray[np.float64]] = None,
    seed: Optional[int] = None,
) -> tuple[NDArray[np.float64], NDArray[np.float64]]:
    """Generate an Ising formulation for approximate TSP.

    Uses permutation matrix encoding with num_cities² binary variables.
    x_{i,t} = 1 if city i is visited at time t.

    Mapped to spins: x_{i,t} = (1 + σ_{i*N+t}) / 2

    Constraints (as penalties):
    1. Each city visited exactly once: Σ_t x_{i,t} = 1 for all i
    2. Each time slot has one city: Σ_i x_{i,t} = 1 for all t
    3. Objective: minimize Σ_{i,j,t} d_{ij} x_{i,t} x_{j,t+1}

    Args:
        num_cities: Number of cities.
        distances: Distance matrix (num_cities x num_cities).
        seed: Random seed for generating random distances.

    Returns:
        (weights, biases) tuple for IsingModel with num_cities² spins.
    """
    rng = np.random.default_rng(seed)
    n = num_cities
    num_spins = n * n

    if distances is None:
        # Generate random symmetric distance matrix
        distances = rng.uniform(1.0, 10.0, size=(n, n))
        distances = (distances + distances.T) / 2.0
        np.fill_diagonal(distances, 0.0)

    weights = np.zeros((num_spins, num_spins), dtype=np.float64)
    biases = np.zeros(num_spins, dtype=np.float64)

    penalty_a = 4.0  # Row constraint
    penalty_b = 4.0  # Column constraint

    def idx(city: int, time: int) -> int:
        return city * n + (time % n)

    # Row constraint: each city visited once → Σ_t x_{i,t} = 1
    for i in range(n):
        for t1 in range(n):
            biases[idx(i, t1)] -= penalty_a  # Linear: -2A per variable
            for t2 in range(t1 + 1, n):
                weights[idx(i, t1), idx(i, t2)] += penalty_a
                weights[idx(i, t2), idx(i, t1)] += penalty_a

    # Column constraint: each time has one city → Σ_i x_{i,t} = 1
    for t in range(n):
        for i1 in range(n):
            biases[idx(i1, t)] -= penalty_b
            for i2 in range(i1 + 1, n):
                weights[idx(i1, t), idx(i2, t)] += penalty_b
                weights[idx(i2, t), idx(i1, t)] += penalty_b

    # Distance objective
    for i in range(n):
        for j in range(n):
            if i != j:
                for t in range(n):
                    s1 = idx(i, t)
                    s2 = idx(j, (t + 1) % n)
                    weights[s1, s2] += distances[i, j] * 0.5
                    weights[s2, s1] += distances[i, j] * 0.5

    return weights, biases
