"""Annealing schedules and simulation runner.

Provides configurable cooling schedules and a runner that executes
the full annealing loop, returning per-step history.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

import numpy as np
from numpy.typing import NDArray

from .ising_model import IsingModel, UpdateMode


class ScheduleType(str, Enum):
    """Temperature annealing schedule types."""

    LINEAR = "linear"
    EXPONENTIAL = "exponential"
    ADAPTIVE = "adaptive"


class AnnealingSchedule:
    """Temperature schedule for simulated annealing.

    Args:
        schedule_type: Type of cooling schedule.
        initial_temp: Starting temperature.
        cooling_rate: Rate parameter (subtracted for linear, multiplied for exponential).
        min_temp: Floor temperature.
        stagnation_window: Steps to look back for adaptive schedule.
    """

    def __init__(
        self,
        schedule_type: ScheduleType = ScheduleType.LINEAR,
        initial_temp: float = 10.0,
        cooling_rate: float = 0.01,
        min_temp: float = 0.01,
        stagnation_window: int = 10,
    ) -> None:
        if initial_temp <= 0:
            raise ValueError("initial_temp must be positive")
        if cooling_rate <= 0:
            raise ValueError("cooling_rate must be positive")

        self.schedule_type = schedule_type
        self.initial_temp = initial_temp
        self.cooling_rate = cooling_rate
        self.min_temp = min_temp
        self.stagnation_window = stagnation_window
        self._temp = initial_temp
        self._energy_history: list[float] = []

    @property
    def temperature(self) -> float:
        """Current temperature."""
        return self._temp

    def reset(self) -> None:
        """Reset schedule to initial state."""
        self._temp = self.initial_temp
        self._energy_history = []

    def step(self, current_energy: Optional[float] = None) -> float:
        """Advance the schedule by one step and return new temperature.

        Args:
            current_energy: Current system energy (needed for adaptive schedule).

        Returns:
            Updated temperature.
        """
        if self.schedule_type == ScheduleType.LINEAR:
            self._temp = max(self._temp - self.cooling_rate, self.min_temp)

        elif self.schedule_type == ScheduleType.EXPONENTIAL:
            alpha = 1.0 - self.cooling_rate
            self._temp = max(self._temp * alpha, self.min_temp)

        elif self.schedule_type == ScheduleType.ADAPTIVE:
            if current_energy is not None:
                self._energy_history.append(current_energy)

            if len(self._energy_history) >= self.stagnation_window:
                recent = self._energy_history[-self.stagnation_window :]
                energy_range = max(recent) - min(recent)
                # If energy stagnates (small range), cool faster
                if energy_range < 1e-6:
                    factor = 1.0 - self.cooling_rate * 2.0
                else:
                    factor = 1.0 - self.cooling_rate * 0.5
                self._temp = max(self._temp * max(factor, 0.5), self.min_temp)
            else:
                self._temp = max(
                    self._temp * (1.0 - self.cooling_rate), self.min_temp
                )

        return self._temp


@dataclass
class StepRecord:
    """Record of a single annealing step."""

    step: int
    spins: NDArray[np.int8]
    energy: float
    temperature: float
    accepted_flips: int


@dataclass
class AnnealingResult:
    """Complete result of an annealing run."""

    history: list[StepRecord] = field(default_factory=list)
    best_spins: NDArray[np.int8] = field(default_factory=lambda: np.array([], dtype=np.int8))
    best_energy: float = float("inf")
    convergence_step: int = 0

    @property
    def energy_history(self) -> list[float]:
        """Extract energy values from history."""
        return [r.energy for r in self.history]

    @property
    def temperature_history(self) -> list[float]:
        """Extract temperature values from history."""
        return [r.temperature for r in self.history]

    @property
    def final_spins(self) -> NDArray[np.int8]:
        """Return the final spin configuration."""
        if self.history:
            return self.history[-1].spins
        return np.array([], dtype=np.int8)


class SimulationRunner:
    """Runs the full simulated annealing loop.

    Args:
        model: The Ising model to anneal.
        schedule: The temperature schedule to follow.
        sweeps_per_temp: Number of Monte Carlo sweeps per temperature step.
        update_mode: Spin update mode.
    """

    def __init__(
        self,
        model: IsingModel,
        schedule: AnnealingSchedule,
        sweeps_per_temp: int = 1,
        update_mode: UpdateMode = UpdateMode.SEQUENTIAL,
    ) -> None:
        self.model = model
        self.schedule = schedule
        self.sweeps_per_temp = sweeps_per_temp
        self.update_mode = update_mode

    def run(self, num_steps: int) -> AnnealingResult:
        """Execute the annealing process.

        Args:
            num_steps: Number of temperature steps.

        Returns:
            AnnealingResult with full history and best solution.
        """
        result = AnnealingResult()
        best_energy = float("inf")
        best_spins = self.model.spins.copy()
        convergence_step = 0

        self.schedule.reset()

        for step_idx in range(num_steps):
            temp = self.schedule.temperature
            total_accepted = 0

            for _ in range(self.sweeps_per_temp):
                accepted = self.model.sweep(temp, self.update_mode)
                total_accepted += accepted

            current_energy = self.model.energy()

            record = StepRecord(
                step=step_idx,
                spins=self.model.spins.copy(),
                energy=current_energy,
                temperature=temp,
                accepted_flips=total_accepted,
            )
            result.history.append(record)

            if current_energy < best_energy:
                best_energy = current_energy
                best_spins = self.model.spins.copy()
                convergence_step = step_idx

            self.schedule.step(current_energy)

        result.best_energy = best_energy
        result.best_spins = best_spins
        result.convergence_step = convergence_step

        return result

    async def run_async(self, num_steps: int):
        """Async generator that yields StepRecord per temperature step.

        Yields:
            StepRecord for each temperature step.
        """
        self.schedule.reset()
        best_energy = float("inf")
        best_spins = self.model.spins.copy()

        for step_idx in range(num_steps):
            temp = self.schedule.temperature
            total_accepted = 0

            for _ in range(self.sweeps_per_temp):
                accepted = self.model.sweep(temp, self.update_mode)
                total_accepted += accepted

            current_energy = self.model.energy()

            record = StepRecord(
                step=step_idx,
                spins=self.model.spins.copy(),
                energy=current_energy,
                temperature=temp,
                accepted_flips=total_accepted,
            )

            if current_energy < best_energy:
                best_energy = current_energy
                best_spins = self.model.spins.copy()

            self.schedule.step(current_energy)
            yield record
