"""Tests for the quantum annealing simulator."""

from __future__ import annotations

import numpy as np
import pytest

from backend.simulator.annealing import AnnealingSchedule, ScheduleType, SimulationRunner
from backend.simulator.ising_model import IsingModel, UpdateMode
from backend.simulator.problems import max_cut


class TestEnergyComputation:
    """Test energy computation for known configurations."""

    def test_energy_computation(self) -> None:
        """Verify energy for a known spin/weight configuration.

        For 4 spins in a ring with J=-1:
        All spins +1: E = -(-1)(1)(1) * 4 = 4 (all aligned, frustrated for antiferro)
        Alternating +1,-1: E = -(-1)(1)(-1) * 4 = -4 (optimal cut)
        """
        weights, biases = max_cut(graph_type="ring", num_nodes=4)
        model = IsingModel(num_spins=4, weights=weights, biases=biases, seed=0)

        # All +1 spins
        model.set_spins(np.array([1, 1, 1, 1], dtype=np.int8))
        e_aligned = model.energy()
        # Each edge contributes -J * s_i * s_j = -(-1)(1)(1) = 1
        # 4 edges in ring: E = sum of (-J_ij * si * sj) for i<j from upper triangle
        # Actually E = -Σ_{i<j} J_ij σ_i σ_j
        # For ring of 4: edges are (0,1),(1,2),(2,3),(3,0) with J=-1
        # Upper triangle pairs with J != 0: (0,1), (1,2), (2,3), (0,3)
        # E = -(-1)(1)(1) - (-1)(1)(1) - (-1)(1)(1) - (-1)(1)(1) = 4
        assert e_aligned == pytest.approx(4.0)

        # Alternating spins: optimal for Max-Cut on ring
        model.set_spins(np.array([1, -1, 1, -1], dtype=np.int8))
        e_alt = model.energy()
        # E = -(-1)(1)(-1) - (-1)(-1)(1) - (-1)(1)(-1) - (-1)(1)(-1)
        #   = -(1) - -(1) - -(1) - -(1) = -1 -1 -1 -1 = -4
        assert e_alt == pytest.approx(-4.0)

        # Alternating should have lower energy
        assert e_alt < e_aligned

    def test_energy_with_biases(self) -> None:
        """Test energy computation with external field."""
        model = IsingModel(
            num_spins=2,
            weights=np.zeros((2, 2), dtype=np.float64),
            biases=np.array([1.0, -1.0], dtype=np.float64),
            seed=0,
        )

        model.set_spins(np.array([1, 1], dtype=np.int8))
        # E = -h_0*s_0 - h_1*s_1 = -1(1) - (-1)(1) = -1 + 1 = 0
        assert model.energy() == pytest.approx(0.0)

        model.set_spins(np.array([1, -1], dtype=np.int8))
        # E = -1(1) - (-1)(-1) = -1 - 1 = -2
        assert model.energy() == pytest.approx(-2.0)


class TestMaxCutRing:
    """Test annealing on the Max-Cut ring problem."""

    def test_max_cut_ring(self) -> None:
        """Run annealing on 8-spin ring, verify finds alternating pattern.

        An 8-spin ring with J=-1 has optimal cut value of 8 (all edges cut)
        achieved by alternating +1/-1 pattern. Energy = -8.
        """
        weights, biases = max_cut(graph_type="ring", num_nodes=8)
        model = IsingModel(num_spins=8, weights=weights, biases=biases, seed=42)

        schedule = AnnealingSchedule(
            schedule_type=ScheduleType.LINEAR,
            initial_temp=5.0,
            cooling_rate=0.005,
            min_temp=0.001,
        )

        runner = SimulationRunner(
            model=model,
            schedule=schedule,
            sweeps_per_temp=10,
            update_mode=UpdateMode.SEQUENTIAL,
        )

        result = runner.run(num_steps=500)

        # Optimal energy for 8-spin ring Max-Cut is -8
        assert result.best_energy == pytest.approx(-8.0)

        # Check alternating pattern (either +1,-1,+1... or -1,+1,-1...)
        best = result.best_spins
        is_alternating = all(
            best[i] != best[(i + 1) % 8] for i in range(8)
        )
        assert is_alternating, f"Expected alternating pattern, got {best}"


class TestLinearCooling:
    """Test linear cooling schedule."""

    def test_linear_cooling(self) -> None:
        """Verify temperature decreases linearly."""
        schedule = AnnealingSchedule(
            schedule_type=ScheduleType.LINEAR,
            initial_temp=10.0,
            cooling_rate=1.0,
            min_temp=0.0,
        )

        temps = [schedule.temperature]
        for _ in range(10):
            schedule.step()
            temps.append(schedule.temperature)

        # Should decrease by 1.0 each step
        for i in range(1, len(temps)):
            expected = max(10.0 - i * 1.0, 0.0)
            assert temps[i] == pytest.approx(expected), f"Step {i}: expected {expected}, got {temps[i]}"

        # Final temp should be at minimum
        assert temps[-1] == pytest.approx(0.0)

    def test_exponential_cooling(self) -> None:
        """Verify temperature decreases exponentially."""
        schedule = AnnealingSchedule(
            schedule_type=ScheduleType.EXPONENTIAL,
            initial_temp=10.0,
            cooling_rate=0.1,  # alpha = 0.9
            min_temp=0.01,
        )

        t0 = schedule.temperature
        schedule.step()
        t1 = schedule.temperature

        # T1 = T0 * 0.9
        assert t1 == pytest.approx(t0 * 0.9)


class TestDeterministicSeeding:
    """Test that same seed produces same results."""

    def test_deterministic_seeding(self) -> None:
        """Same seed should produce identical simulation results."""
        def run_with_seed(seed: int) -> list[float]:
            weights, biases = max_cut(graph_type="ring", num_nodes=8)
            model = IsingModel(num_spins=8, weights=weights, biases=biases, seed=seed)
            schedule = AnnealingSchedule(
                schedule_type=ScheduleType.LINEAR,
                initial_temp=5.0,
                cooling_rate=0.05,
            )
            runner = SimulationRunner(model=model, schedule=schedule, sweeps_per_temp=5)
            result = runner.run(num_steps=50)
            return result.energy_history

        # Same seed should give same results
        history1 = run_with_seed(12345)
        history2 = run_with_seed(12345)
        assert history1 == history2

        # Different seed should (very likely) give different results
        history3 = run_with_seed(99999)
        assert history1 != history3


class TestMetropolisAcceptance:
    """Test Metropolis acceptance criterion."""

    def test_metropolis_acceptance_zero_temp(self) -> None:
        """At T=0, only energy-lowering moves should be accepted."""
        # Create a simple 2-spin system with J=-1 (antiferromagnetic)
        weights = np.array([[0.0, -1.0], [-1.0, 0.0]], dtype=np.float64)
        biases = np.zeros(2, dtype=np.float64)
        model = IsingModel(num_spins=2, weights=weights, biases=biases, seed=42)

        # Set both spins aligned (high energy for antiferro)
        model.set_spins(np.array([1, 1], dtype=np.int8))

        # At T=0, flipping spin 0 should improve energy → accept
        # ΔE = -2 * s_0 * (J_{01} * s_1 + h_0) = -2 * 1 * (-1 * 1) = 2 > 0
        # Wait, let's check: aligned spins with J=-1
        # E_before = -J_{01} * s_0 * s_1 = -(-1)(1)(1) = 1
        # After flipping s_0 to -1: E_after = -(-1)(-1)(1) = -1
        # ΔE = E_after - E_before = -1 - 1 = -2 → improving → should accept
        de = model.delta_energy(0)
        assert de < 0, f"Expected negative ΔE for improving move, got {de}"

        accepted = model.metropolis_step(0, temperature=0.0)
        assert accepted, "Should accept energy-lowering move at T=0"

        # Now spins are anti-aligned (optimal), flipping should worsen → reject
        assert model.spins[0] == -1
        de2 = model.delta_energy(0)
        assert de2 > 0, f"Expected positive ΔE for worsening move, got {de2}"

        accepted2 = model.metropolis_step(0, temperature=0.0)
        assert not accepted2, "Should reject energy-raising move at T=0"

    def test_metropolis_high_temp(self) -> None:
        """At very high temperature, most moves should be accepted."""
        weights = np.array([[0.0, -1.0], [-1.0, 0.0]], dtype=np.float64)
        model = IsingModel(num_spins=2, weights=weights, seed=42)

        # Run many sweeps at very high temperature
        total_accepted = 0
        total_attempts = 0
        for _ in range(100):
            accepted = model.sweep(temperature=1000.0)
            total_accepted += accepted
            total_attempts += model.num_spins

        acceptance_rate = total_accepted / total_attempts
        # At T=1000, virtually all moves should be accepted
        assert acceptance_rate > 0.8, f"Expected high acceptance at T=1000, got {acceptance_rate}"


class TestLocalField:
    """Test local field computation."""

    def test_local_field(self) -> None:
        """Verify local field calculation."""
        weights = np.array(
            [[0.0, 2.0, -1.0], [2.0, 0.0, 0.5], [-1.0, 0.5, 0.0]],
            dtype=np.float64,
        )
        biases = np.array([0.5, -0.5, 1.0], dtype=np.float64)
        model = IsingModel(num_spins=3, weights=weights, biases=biases, seed=0)
        model.set_spins(np.array([1, -1, 1], dtype=np.int8))

        # h_eff_0 = J_{00}*s_0 + J_{01}*s_1 + J_{02}*s_2 + h_0
        #         = 0*1 + 2*(-1) + (-1)*1 + 0.5 = -2 - 1 + 0.5 = -2.5
        assert model.local_field(0) == pytest.approx(-2.5)


class TestUpdateModes:
    """Test different spin update modes."""

    def test_all_modes_reduce_energy(self) -> None:
        """All update modes should reduce energy during annealing."""
        for mode in UpdateMode:
            weights, biases = max_cut(graph_type="ring", num_nodes=8)
            model = IsingModel(num_spins=8, weights=weights, biases=biases, seed=42)

            schedule = AnnealingSchedule(
                schedule_type=ScheduleType.LINEAR,
                initial_temp=5.0,
                cooling_rate=0.05,
            )

            runner = SimulationRunner(
                model=model,
                schedule=schedule,
                sweeps_per_temp=5,
                update_mode=mode,
            )

            result = runner.run(num_steps=50)

            # Energy should generally decrease (or stay at optimum if started there)
            initial_energy = result.history[0].energy
            assert result.best_energy <= initial_energy, (
                f"Mode {mode}: best energy {result.best_energy} > initial {initial_energy}"
            )
