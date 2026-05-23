"""Metrics for evaluating optimization results."""

from __future__ import annotations

from typing import Optional

import numpy as np
from numpy.typing import NDArray


def compute_cut_value(
    spins: NDArray[np.int8], weights: NDArray[np.float64]
) -> float:
    """Compute the cut value for a Max-Cut solution.

    An edge (i,j) is cut when σ_i ≠ σ_j. For Max-Cut with J_ij = -1 couplings,
    the cut value counts the number of anti-aligned pairs weighted by |J_ij|.

    Args:
        spins: Spin configuration (+1/-1).
        weights: Coupling matrix.

    Returns:
        Total cut value (number of cut edges for unit-weight graphs).
    """
    n = len(spins)
    cut_value = 0.0
    spins_f = spins.astype(np.float64)
    for i in range(n):
        for j in range(i + 1, n):
            if weights[i, j] != 0:
                # Edge is cut when spins differ; for J<0, anti-aligned minimizes energy
                cut_value += abs(weights[i, j]) * (1.0 - spins_f[i] * spins_f[j]) / 2.0
    return float(cut_value)


def time_to_solution(
    energy_history: list[float],
    target: float,
) -> Optional[int]:
    """Find the first step at which energy reaches the target.

    Args:
        energy_history: List of energy values per step.
        target: Target energy to reach.

    Returns:
        Step index where energy first reaches target, or None if never reached.
    """
    for i, e in enumerate(energy_history):
        if e <= target:
            return i
    return None


def convergence_rate(energy_history: list[float]) -> float:
    """Compute the convergence rate as average energy drop per step.

    Uses linear regression slope on the energy history.

    Args:
        energy_history: List of energy values per step.

    Returns:
        Average energy change per step (negative means improving).
    """
    if len(energy_history) < 2:
        return 0.0

    steps = np.arange(len(energy_history), dtype=np.float64)
    energies = np.array(energy_history, dtype=np.float64)

    # Linear regression: slope
    n = len(steps)
    slope = (n * np.dot(steps, energies) - steps.sum() * energies.sum()) / (
        n * np.dot(steps, steps) - steps.sum() ** 2
    )
    return float(slope)


def solution_quality(found_energy: float, optimal_energy: float) -> float:
    """Compute solution quality as a ratio.

    Returns 1.0 for optimal solution, <1.0 for suboptimal.

    Args:
        found_energy: Energy of the found solution.
        optimal_energy: Known optimal energy.

    Returns:
        Quality ratio in [0, 1]. Returns 1.0 if found equals optimal.
    """
    if optimal_energy == 0:
        if found_energy == 0:
            return 1.0
        return 0.0

    # Both should be negative for minimization problems
    if optimal_energy < 0:
        ratio = found_energy / optimal_energy
        return float(min(max(ratio, 0.0), 1.0))
    else:
        # For positive optimal, closer to 0 is better
        if found_energy <= 0:
            return 1.0
        ratio = optimal_energy / found_energy
        return float(min(max(ratio, 0.0), 1.0))
