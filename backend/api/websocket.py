"""WebSocket endpoint for streaming simulation updates."""

from __future__ import annotations

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from ..models.schemas import SimulationConfig
from ..simulator.annealing import AnnealingSchedule, ScheduleType, SimulationRunner
from ..simulator.ising_model import IsingModel, UpdateMode
from ..simulator.problems import graph_partition, max_cut, sat_approx, tsp_approx

import numpy as np

ws_router = APIRouter()


def _build_model_from_config(config: SimulationConfig) -> tuple[IsingModel, AnnealingSchedule]:
    """Build IsingModel and AnnealingSchedule from config."""
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
        weights, biases = tsp_approx(num_cities=num_cities, seed=config.seed)
    else:
        weights = np.zeros((config.num_spins, config.num_spins), dtype=np.float64)
        biases = np.zeros(config.num_spins, dtype=np.float64)

    model = IsingModel(
        num_spins=len(biases),
        weights=weights,
        biases=biases,
        seed=config.seed,
    )

    try:
        schedule_type = ScheduleType(config.schedule_type)
    except ValueError:
        schedule_type = ScheduleType.LINEAR

    schedule = AnnealingSchedule(
        schedule_type=schedule_type,
        initial_temp=config.initial_temp,
        cooling_rate=config.cooling_rate,
    )

    return model, schedule


@ws_router.websocket("/ws/simulate")
async def websocket_simulate(websocket: WebSocket) -> None:
    """WebSocket endpoint that streams simulation spin state updates.

    Accepts a SimulationConfig as JSON, then streams SpinState updates
    for each sweep as JSON messages.
    """
    await websocket.accept()

    try:
        # Receive configuration
        data = await websocket.receive_text()
        config = SimulationConfig.model_validate_json(data)

        model, schedule = _build_model_from_config(config)

        try:
            update_mode = UpdateMode(config.update_mode)
        except ValueError:
            update_mode = UpdateMode.SEQUENTIAL

        runner = SimulationRunner(
            model=model,
            schedule=schedule,
            sweeps_per_temp=config.sweeps_per_temp,
            update_mode=update_mode,
        )

        # Stream results
        async for record in runner.run_async(config.steps_per_temp):
            message = {
                "type": "spin_update",
                "data": {
                    "spins": record.spins.tolist(),
                    "energy": record.energy,
                    "temperature": record.temperature,
                    "step": record.step,
                },
            }
            await websocket.send_text(json.dumps(message))
            # Yield control to event loop
            await asyncio.sleep(0)

        # Send completion message
        await websocket.send_text(json.dumps({"type": "complete"}))

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_text(
                json.dumps({"type": "error", "message": str(e)})
            )
        except Exception:
            pass
