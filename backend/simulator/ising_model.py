"""Ising model simulator mirroring RTL behavior.

Implements a classical Ising model with Metropolis-Hastings Monte Carlo updates,
supporting sequential, checkerboard, and parallel update modes.
"""

from __future__ import annotations

from enum import Enum
from typing import Optional

import numpy as np
from numpy.typing import NDArray


class UpdateMode(str, Enum):
    """Spin update scheduling modes."""

    SEQUENTIAL = "sequential"
    CHECKERBOARD = "checkerboard"
    PARALLEL = "parallel"


class IsingModel:
    """Classical Ising model simulator.

    Energy: E = -Σ_{i<j} J_ij σ_i σ_j - Σ_i h_i σ_i
    where spins σ_i ∈ {+1, -1}.

    Args:
        num_spins: Number of spins in the system.
        weights: Coupling matrix J (num_spins x num_spins). Symmetric.
        biases: External field vector h (num_spins,).
        seed: Random seed for reproducibility.
    """

    def __init__(
        self,
        num_spins: int,
        weights: Optional[NDArray[np.float64]] = None,
        biases: Optional[NDArray[np.float64]] = None,
        seed: Optional[int] = None,
    ) -> None:
        if num_spins < 1:
            raise ValueError("num_spins must be >= 1")

        self.num_spins = num_spins
        self.rng = np.random.default_rng(seed)

        if weights is not None:
            if weights.shape != (num_spins, num_spins):
                raise ValueError(
                    f"weights shape {weights.shape} doesn't match ({num_spins}, {num_spins})"
                )
            self.weights = weights.astype(np.float64)
        else:
            self.weights = np.zeros((num_spins, num_spins), dtype=np.float64)

        if biases is not None:
            if biases.shape != (num_spins,):
                raise ValueError(
                    f"biases shape {biases.shape} doesn't match ({num_spins},)"
                )
            self.biases = biases.astype(np.float64)
        else:
            self.biases = np.zeros(num_spins, dtype=np.float64)

        # Initialize spins randomly to +1/-1
        self.spins: NDArray[np.int8] = (
            2 * self.rng.integers(0, 2, size=num_spins).astype(np.int8) - 1
        )

    def energy(self) -> float:
        """Compute total energy: E = -Σ_{i<j} J_ij σ_i σ_j - Σ_i h_i σ_i."""
        spins_f = self.spins.astype(np.float64)
        # Use upper triangle of weights for i<j sum
        coupling_energy = -np.dot(spins_f, np.triu(self.weights, k=1) @ spins_f)
        field_energy = -np.dot(self.biases, spins_f)
        return float(coupling_energy + field_energy)

    def local_field(self, i: int) -> float:
        """Compute effective local field at spin i.

        h_eff_i = Σ_j J_ij σ_j + h_i
        """
        return float(
            np.dot(self.weights[i], self.spins.astype(np.float64)) + self.biases[i]
        )

    def delta_energy(self, i: int) -> float:
        """Compute energy change from flipping spin i.

        ΔE = 2 σ_i h_eff_i = 2 σ_i (Σ_j J_ij σ_j + h_i)
        """
        return 2.0 * self.spins[i] * self.local_field(i)

    def metropolis_step(self, i: int, temperature: float) -> bool:
        """Attempt a single Metropolis-Hastings spin flip.

        P(flip) = min(1, exp(-ΔE / T))

        Args:
            i: Spin index to attempt flipping.
            temperature: Current temperature.

        Returns:
            True if spin was flipped.
        """
        de = self.delta_energy(i)

        if de <= 0:
            self.spins[i] *= -1
            return True

        if temperature <= 0:
            return False

        acceptance_prob = np.exp(-de / temperature)
        if self.rng.random() < acceptance_prob:
            self.spins[i] *= -1
            return True

        return False

    def sweep(
        self, temperature: float, mode: UpdateMode = UpdateMode.SEQUENTIAL
    ) -> int:
        """Perform one full sweep over all spins.

        Args:
            temperature: Current temperature for Metropolis acceptance.
            mode: Update scheduling mode.

        Returns:
            Number of accepted flips.
        """
        if mode == UpdateMode.SEQUENTIAL:
            return self._sweep_sequential(temperature)
        elif mode == UpdateMode.CHECKERBOARD:
            return self._sweep_checkerboard(temperature)
        elif mode == UpdateMode.PARALLEL:
            return self._sweep_parallel(temperature)
        else:
            raise ValueError(f"Unknown update mode: {mode}")

    def _sweep_sequential(self, temperature: float) -> int:
        """Sequential update: visit spins in random order."""
        order = self.rng.permutation(self.num_spins)
        accepted = 0
        for i in order:
            if self.metropolis_step(i, temperature):
                accepted += 1
        return accepted

    def _sweep_checkerboard(self, temperature: float) -> int:
        """Checkerboard update: even-indexed then odd-indexed spins."""
        accepted = 0
        for parity in (0, 1):
            indices = np.arange(parity, self.num_spins, 2)
            self.rng.shuffle(indices)
            for i in indices:
                if self.metropolis_step(i, temperature):
                    accepted += 1
        return accepted

    def _sweep_parallel(self, temperature: float) -> int:
        """Parallel (vectorized) update: compute all ΔE simultaneously.

        All spins are evaluated at once, but flip decisions are independent.
        This mirrors the RTL's parallel update capability.
        """
        spins_f = self.spins.astype(np.float64)
        local_fields = self.weights @ spins_f + self.biases
        delta_e = 2.0 * spins_f * local_fields

        # Determine which spins to flip
        accept_improving = delta_e <= 0
        if temperature > 0:
            probs = np.exp(-np.clip(delta_e, 0, 500) / temperature)
            random_vals = self.rng.random(self.num_spins)
            accept_thermal = random_vals < probs
            accept = accept_improving | accept_thermal
        else:
            accept = accept_improving

        accepted = int(np.sum(accept))
        self.spins[accept] *= -1
        return accepted

    def set_spins(self, spins: NDArray[np.int8]) -> None:
        """Set spin configuration directly."""
        if spins.shape != (self.num_spins,):
            raise ValueError(
                f"spins shape {spins.shape} doesn't match ({self.num_spins},)"
            )
        if not np.all(np.isin(spins, [-1, 1])):
            raise ValueError("All spins must be +1 or -1")
        self.spins = spins.copy().astype(np.int8)

    def randomize_spins(self) -> None:
        """Randomize all spins."""
        self.spins = (
            2 * self.rng.integers(0, 2, size=self.num_spins).astype(np.int8) - 1
        )
