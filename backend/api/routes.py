"""FastAPI routes for the optimization accelerator API."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional

import numpy as np
from fastapi import APIRouter, HTTPException

from ..models.schemas import (
    BenchmarkConfig,
    BenchmarkResult,
    BenchmarkStatistics,
    ParameterInfo,
    PortInfo,
    RTLModule,
    SimulationConfig,
    SimulationResult,
    SpinState,
)
from ..simulator.annealing import AnnealingSchedule, ScheduleType, SimulationRunner
from ..simulator.ising_model import IsingModel, UpdateMode
from ..simulator.problems import graph_partition, max_cut, sat_approx, tsp_approx

router = APIRouter(prefix="/api", tags=["simulation"])

# Store last simulation result for stateful queries
_last_result: Optional[SimulationResult] = None
_last_spin_state: Optional[SpinState] = None

# RTL directory relative to project root
RTL_DIR = Path(__file__).resolve().parent.parent.parent / "rtl"


def _build_simulation(config: SimulationConfig) -> tuple[IsingModel, AnnealingSchedule]:
    """Build IsingModel and AnnealingSchedule from config."""
    # Parse problem type
    problem_type = config.problem_type.lower()
    if problem_type.startswith("max_cut"):
        graph_type = problem_type.replace("max_cut_", "") if "_" in problem_type[8:] else "ring"
        weights, biases = max_cut(graph_type=graph_type, num_nodes=config.num_spins, seed=config.seed)
    elif problem_type == "graph_partition":
        weights, biases = graph_partition(num_nodes=config.num_spins, seed=config.seed)
    elif problem_type == "sat_approx":
        weights, biases = sat_approx(num_vars=config.num_spins, seed=config.seed)
    elif problem_type == "tsp_approx":
        num_cities = int(np.sqrt(config.num_spins))
        if num_cities * num_cities != config.num_spins:
            raise HTTPException(
                status_code=400,
                detail="For TSP, num_spins must be a perfect square (cities²)",
            )
        weights, biases = tsp_approx(num_cities=num_cities, seed=config.seed)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown problem type: {config.problem_type}")

    model = IsingModel(
        num_spins=len(biases),
        weights=weights,
        biases=biases,
        seed=config.seed,
    )

    try:
        schedule_type = ScheduleType(config.schedule_type)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown schedule type: {config.schedule_type}. Use linear, exponential, or adaptive.",
        )

    schedule = AnnealingSchedule(
        schedule_type=schedule_type,
        initial_temp=config.initial_temp,
        cooling_rate=config.cooling_rate,
    )

    return model, schedule


def _get_update_mode(mode_str: str) -> UpdateMode:
    """Parse update mode string."""
    try:
        return UpdateMode(mode_str)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown update mode: {mode_str}. Use sequential, checkerboard, or parallel.",
        )


@router.post("/simulate", response_model=SimulationResult)
async def simulate(config: SimulationConfig) -> SimulationResult:
    """Run a simulation with the given configuration."""
    global _last_result, _last_spin_state

    model, schedule = _build_simulation(config)
    update_mode = _get_update_mode(config.update_mode)

    runner = SimulationRunner(
        model=model,
        schedule=schedule,
        sweeps_per_temp=config.sweeps_per_temp,
        update_mode=update_mode,
    )

    result = runner.run(config.steps_per_temp)

    sim_result = SimulationResult(
        final_spins=result.final_spins.tolist(),
        best_energy=result.best_energy,
        energy_history=result.energy_history,
        temperature_history=result.temperature_history,
        convergence_step=result.convergence_step,
    )

    _last_result = sim_result
    if result.history:
        last = result.history[-1]
        _last_spin_state = SpinState(
            spins=last.spins.tolist(),
            energy=last.energy,
            temperature=last.temperature,
            step=last.step,
        )

    return sim_result


@router.post("/benchmark", response_model=BenchmarkResult)
async def benchmark(config: BenchmarkConfig) -> BenchmarkResult:
    """Run multiple simulation runs and return aggregate statistics."""
    results: list[SimulationResult] = []

    for run_idx in range(config.num_runs):
        sim_config = SimulationConfig(
            num_spins=config.problem_size,
            schedule_type=config.schedule_type,
            initial_temp=config.initial_temp,
            cooling_rate=config.cooling_rate,
            steps_per_temp=config.steps_per_temp,
            sweeps_per_temp=config.sweeps_per_temp,
            seed=run_idx if config.num_runs > 1 else None,
            problem_type=config.problem_type,
        )

        model, schedule = _build_simulation(sim_config)
        runner = SimulationRunner(
            model=model,
            schedule=schedule,
            sweeps_per_temp=sim_config.sweeps_per_temp,
        )
        anneal_result = runner.run(sim_config.steps_per_temp)

        results.append(
            SimulationResult(
                final_spins=anneal_result.final_spins.tolist(),
                best_energy=anneal_result.best_energy,
                energy_history=anneal_result.energy_history,
                temperature_history=anneal_result.temperature_history,
                convergence_step=anneal_result.convergence_step,
            )
        )

    energies = [r.best_energy for r in results]
    best_e = min(energies)
    statistics = BenchmarkStatistics(
        mean_energy=float(np.mean(energies)),
        std_energy=float(np.std(energies)),
        best_energy=best_e,
        worst_energy=max(energies),
        mean_convergence_step=float(np.mean([r.convergence_step for r in results])),
        success_rate=sum(1 for e in energies if abs(e - best_e) < 1e-10) / len(energies),
    )

    return BenchmarkResult(results=results, statistics=statistics)


@router.get("/spin-state", response_model=SpinState)
async def get_spin_state() -> SpinState:
    """Return the current (last) simulation spin state."""
    if _last_spin_state is None:
        raise HTTPException(status_code=404, detail="No simulation has been run yet")
    return _last_spin_state


@router.get("/energy")
async def get_energy() -> dict:
    """Return energy history from the last simulation run."""
    if _last_result is None:
        raise HTTPException(status_code=404, detail="No simulation has been run yet")
    return {"energy_history": _last_result.energy_history}


@router.get("/timeline")
async def get_timeline() -> dict:
    """Return temperature and energy over time for the last run."""
    if _last_result is None:
        raise HTTPException(status_code=404, detail="No simulation has been run yet")
    return {
        "energy": _last_result.energy_history,
        "temperature": _last_result.temperature_history,
        "steps": list(range(len(_last_result.energy_history))),
    }


def _parse_sv_module(filepath: Path) -> Optional[RTLModule]:
    """Parse a SystemVerilog file for module metadata."""
    try:
        source = filepath.read_text()
    except Exception:
        return None

    # Extract description from header comments
    description_lines = []
    for line in source.split("\n"):
        stripped = line.strip()
        if stripped.startswith("//"):
            description_lines.append(stripped.lstrip("/ ").strip())
        elif stripped.startswith("/*"):
            description_lines.append(stripped.lstrip("/* ").rstrip("*/").strip())
        elif stripped and not stripped.startswith("*"):
            break
        elif stripped.startswith("*"):
            description_lines.append(stripped.lstrip("* ").rstrip("*/").strip())

    description = " ".join(line for line in description_lines if line)

    # Extract module name
    module_match = re.search(r"module\s+(\w+)", source)
    if not module_match:
        return None
    module_name = module_match.group(1)

    # Extract parameters
    parameters: list[ParameterInfo] = []
    param_pattern = re.compile(r"parameter\s+(?:\w+\s+)?(\w+)\s*=\s*([^,;\)]+)")
    for m in param_pattern.finditer(source):
        parameters.append(ParameterInfo(name=m.group(1), default_value=m.group(2).strip()))

    # Extract ports
    ports: list[PortInfo] = []
    port_pattern = re.compile(
        r"(input|output|inout)\s+(?:wire\s+|reg\s+|logic\s+)?(\[[\d:]+\]\s+)?(\w+)"
    )
    for m in port_pattern.finditer(source):
        direction = m.group(1)
        width = m.group(2).strip() if m.group(2) else "1"
        name = m.group(3)
        ports.append(PortInfo(name=name, direction=direction, width=width))

    return RTLModule(
        name=module_name,
        description=description[:500] if description else "",
        ports=ports,
        parameters=parameters,
        source_code=source,
    )


@router.get("/rtl/modules", response_model=list[RTLModule])
async def get_rtl_modules() -> list[RTLModule]:
    """Read RTL .sv files and return module metadata."""
    if not RTL_DIR.exists():
        raise HTTPException(status_code=404, detail="RTL directory not found")

    modules = []
    for sv_file in sorted(RTL_DIR.glob("*.sv")):
        module = _parse_sv_module(sv_file)
        if module:
            # Strip source code from listing (use /source endpoint for full source)
            module.source_code = ""
            modules.append(module)

    return modules


@router.get("/rtl/modules/{name}/source")
async def get_rtl_module_source(name: str) -> dict:
    """Return raw SystemVerilog source for a specific module."""
    if not RTL_DIR.exists():
        raise HTTPException(status_code=404, detail="RTL directory not found")

    # Search for matching .sv file
    for sv_file in RTL_DIR.glob("*.sv"):
        source = sv_file.read_text()
        if re.search(rf"module\s+{re.escape(name)}\b", source):
            return {"name": name, "source": source, "file": sv_file.name}

    raise HTTPException(status_code=404, detail=f"Module '{name}' not found")
