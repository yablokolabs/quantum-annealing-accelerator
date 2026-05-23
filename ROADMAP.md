# 🗺 Roadmap

> Development roadmap for the Quantum-Inspired Optimization Accelerator.

---

## Phase 1: Core Architecture ✅

- [x] Synthesizable SystemVerilog RTL (9 modules)
- [x] Package definitions with shared types and fixed-point utilities (`qa_pkg`)
- [x] Parameterized top-level integration (`qa_top`)
- [x] Memory-mapped configuration register bank (`config_registers`)
- [x] Programmable temperature schedule FSM (`anneal_controller`)
- [x] Scalable p-bit spin array with 3 update strategies (`spin_array`)
- [x] Hardware-linearized sigmoid spin cell (`spin_cell`)
- [x] Local field computation with optional pipelining (`ising_coupler`)
- [x] Dual-mode PRNG — LFSR and xorshift (`rng_module`)
- [x] Full Hamiltonian computation with convergence detection (`energy_tracker`)
- [x] Verilator lint-clean (all modules pass `-Wall`)
- [x] Directed testbenches for all modules (6 testbenches)
- [x] Integration test: Max-Cut on 8-spin antiferromagnetic ring
- [x] Python digital-twin simulator with Numba JIT acceleration
- [x] FastAPI backend with REST API and WebSocket streaming
- [x] React visualization frontend
- [x] Docker Compose deployment with health checks
- [x] GitHub Actions CI/CD (RTL lint, backend tests, frontend build)
- [x] FPGA timing constraints (Xilinx XDC + Intel SDC, 100 MHz)

## Phase 2: FPGA Prototyping (Planned)

- [ ] Xilinx Artix-7 (XC7A100T) / Zynq-7020 target
- [ ] Vivado synthesis and implementation scripts
- [ ] On-chip BRAM weight storage with initialization
- [ ] AXI4-Lite register interface for PS-PL communication
- [ ] AXI4 DMA for bulk weight/bias loading
- [ ] ILA (Integrated Logic Analyzer) debug cores
- [ ] Resource utilization analysis and timing reports
- [ ] Intel Cyclone V / Cyclone 10 LP port
- [ ] Quartus synthesis scripts and pin assignments
- [ ] Board-level bring-up on commercial dev boards

## Phase 3: Scalability (Planned)

- [ ] 64-spin array with auto-pipelining
- [ ] 256-spin array with hierarchical interconnect
- [ ] Sparse weight matrix support (CSR format in BRAM)
- [ ] Block RAM weight storage with sequential loading
- [ ] Multi-FPGA interconnect exploration (GTX/GTH transceivers)
- [ ] Tiled architecture for modular spin-block scaling
- [ ] Performance profiling and bottleneck analysis
- [ ] Power estimation across spin-count configurations

## Phase 4: Advanced Features (Planned)

- [ ] Parallel tempering (replica exchange Monte Carlo)
- [ ] Simulated quantum annealing (SQA) with Suzuki-Trotter decomposition
- [ ] Population annealing with weighted resampling
- [ ] Problem-specific optimizations (Max-Cut, TSP, SAT)
- [ ] Dynamic problem loading without re-synthesis
- [ ] Multi-objective optimization support
- [ ] Interrupt-driven completion notification
- [ ] Hardware performance counters (cycles, flips, energy evaluations)
- [ ] ASIC feasibility study (28nm / 7nm node analysis)

## Phase 5: System Integration (Future)

- [ ] PCIe Gen3/Gen4 host interface (DMA engine)
- [ ] Linux kernel device driver (`/dev/qa_accel`)
- [ ] Python API library (`pip install qa-accelerator`)
- [ ] C/C++ low-level API with shared memory
- [ ] Cloud deployment on AWS F1 instances (Xilinx UltraScale+)
- [ ] Cloud deployment on Azure NP-series (Xilinx Alveo)
- [ ] Kubernetes-based multi-accelerator scheduling
- [ ] REST/gRPC service wrapper for remote execution
- [ ] Benchmark suite against commercial solvers (Gurobi, CPLEX)
- [ ] Academic paper and open-source release

---

## Timeline

```mermaid
gantt
    title Development Timeline
    dateFormat YYYY-Q
    axisFormat %Y-Q%q

    section Phase 1
    Core RTL & Simulation    :done, p1, 2024-Q1, 2024-Q4

    section Phase 2
    FPGA Prototyping         :active, p2, 2025-Q1, 2025-Q2

    section Phase 3
    Scalability              : p3, 2025-Q2, 2025-Q4

    section Phase 4
    Advanced Features        : p4, 2025-Q3, 2026-Q2

    section Phase 5
    System Integration       : p5, 2026-Q1, 2026-Q4
```

---

<div align="center">
<sub>Built by <b>Yabloko Labs</b> · Roadmap updated as milestones are achieved</sub>
</div>
