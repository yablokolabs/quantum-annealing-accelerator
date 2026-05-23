"""Pydantic models for API request/response schemas."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class SimulationConfig(BaseModel):
    """Configuration for a simulation run."""

    num_spins: int = Field(default=8, ge=1, le=4096, description="Number of spins")
    schedule_type: str = Field(default="linear", description="Cooling schedule: linear, exponential, adaptive")
    initial_temp: float = Field(default=10.0, gt=0, description="Starting temperature")
    cooling_rate: float = Field(default=0.01, gt=0, description="Cooling rate parameter")
    steps_per_temp: int = Field(default=100, ge=1, description="Number of temperature steps")
    sweeps_per_temp: int = Field(default=1, ge=1, description="MC sweeps per temperature step")
    seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")
    problem_type: str = Field(default="max_cut_ring", description="Problem type to solve")
    update_mode: str = Field(default="sequential", description="Update mode: sequential, checkerboard, parallel")


class SpinState(BaseModel):
    """Snapshot of simulation state at a point in time."""

    spins: list[int] = Field(description="Spin values (+1/-1)")
    energy: float = Field(description="Current energy")
    temperature: float = Field(description="Current temperature")
    step: int = Field(description="Step index")


class SimulationResult(BaseModel):
    """Result of a completed simulation."""

    final_spins: list[int] = Field(description="Final spin configuration")
    best_energy: float = Field(description="Best energy found")
    energy_history: list[float] = Field(description="Energy at each step")
    temperature_history: list[float] = Field(description="Temperature at each step")
    convergence_step: int = Field(description="Step where best energy was found")


class BenchmarkConfig(BaseModel):
    """Configuration for benchmark runs."""

    problem_type: str = Field(default="max_cut_ring", description="Problem type")
    problem_size: int = Field(default=8, ge=2, le=1024, description="Problem size (num nodes/spins)")
    num_runs: int = Field(default=5, ge=1, le=100, description="Number of independent runs")
    schedule_type: str = Field(default="linear", description="Cooling schedule type")
    initial_temp: float = Field(default=10.0, gt=0)
    cooling_rate: float = Field(default=0.01, gt=0)
    steps_per_temp: int = Field(default=100, ge=1)
    sweeps_per_temp: int = Field(default=1, ge=1)


class BenchmarkStatistics(BaseModel):
    """Aggregate statistics from benchmark runs."""

    mean_energy: float
    std_energy: float
    best_energy: float
    worst_energy: float
    mean_convergence_step: float
    success_rate: float = Field(description="Fraction of runs finding best energy")


class BenchmarkResult(BaseModel):
    """Result of a benchmark suite."""

    results: list[SimulationResult] = Field(description="Individual run results")
    statistics: BenchmarkStatistics = Field(description="Aggregate statistics")


class PortInfo(BaseModel):
    """Information about a SystemVerilog module port."""

    name: str
    direction: str = Field(description="input, output, or inout")
    width: str = Field(default="1", description="Port width")


class ParameterInfo(BaseModel):
    """Information about a SystemVerilog module parameter."""

    name: str
    default_value: str = ""


class RTLModule(BaseModel):
    """Metadata for an RTL (SystemVerilog) module."""

    name: str = Field(description="Module name")
    description: str = Field(default="", description="Description from header comments")
    ports: list[PortInfo] = Field(default_factory=list, description="Module ports")
    parameters: list[ParameterInfo] = Field(default_factory=list, description="Module parameters")
    source_code: str = Field(default="", description="Raw SystemVerilog source")
