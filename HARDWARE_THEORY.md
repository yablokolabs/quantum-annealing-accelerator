# Hardware Theory

> Deep technical background on combinatorial optimization, Ising machines, p-bit computing, and digital annealing systems.

---

## Table of Contents

1. [Combinatorial Optimization](#1-combinatorial-optimization)
2. [Ising Machines: History & Landscape](#2-ising-machines-history--landscape)
3. [Quantum vs. Quantum-Inspired](#3-quantum-vs-quantum-inspired)
4. [P-Bit Computing](#4-p-bit-computing)
5. [Digital Annealing Systems](#5-digital-annealing-systems)
6. [FPGA Implementation Advantages](#6-fpga-implementation-advantages)
7. [Benchmark Problems & Ising Formulations](#7-benchmark-problems--ising-formulations)
8. [References](#8-references)

---

## 1. Combinatorial Optimization

### 1.1 The Problem Class

Combinatorial optimization problems ask: given a finite but exponentially large set of candidate solutions, find the one that minimizes (or maximizes) an objective function subject to constraints. These problems arise in:

- **Logistics:** Vehicle routing, supply chain scheduling
- **Finance:** Portfolio optimization, risk assessment
- **Drug Discovery:** Molecular conformation, protein folding
- **Machine Learning:** Feature selection, neural architecture search
- **VLSI Design:** Placement, routing, timing optimization
- **Telecommunications:** Network design, frequency assignment

### 1.2 NP-Hardness

Many combinatorial problems are **NP-hard** — no known polynomial-time algorithm solves them exactly. The number of candidate solutions grows exponentially with problem size:

| Problem | Variables | Solution Space |
|---|---|---|
| Max-Cut | $N$ nodes | $2^N$ partitions |
| 3-SAT | $N$ variables | $2^N$ assignments |
| TSP | $N$ cities | $N!/2$ tours |
| Graph Coloring | $N$ nodes, $k$ colors | $k^N$ colorings |

For $N = 100$, even $2^{100} \approx 10^{30}$ solutions cannot be exhaustively searched by any classical computer.

### 1.3 Approximation Approaches

Since exact solutions are intractable, practical approaches include:

| Approach | Quality | Speed | Example |
|---|---|---|---|
| Exact solvers | Optimal | Exponential | Branch-and-bound, ILP |
| Heuristics | Good | Fast | Greedy, local search |
| Metaheuristics | Near-optimal | Moderate | Simulated annealing, genetic algorithms |
| **Ising machines** | **Near-optimal** | **Very fast** | **Digital annealing, quantum annealing** |

Ising machines — both quantum and classical — represent a hardware-accelerated approach to metaheuristic optimization, potentially achieving orders-of-magnitude speedup over software implementations.

---

## 2. Ising Machines: History & Landscape

### 2.1 Origins

The Ising model was proposed by Wilhelm Lenz in 1920 and solved in 1D by his student Ernst Ising in 1924. Originally a model of ferromagnetism, it was recognized in the 1980s–1990s as a universal framework for combinatorial optimization when Barahona (1982) proved that finding the ground state of a general Ising model is NP-hard.

### 2.2 Industrial Ising Machine Implementations

#### Fujitsu Digital Annealer (2018–present)

Fujitsu's Digital Annealer Unit (DAU) is the most commercially successful digital annealing system:

- **Architecture:** Application-specific CMOS circuit implementing parallel simulated annealing
- **Scale:** 1st gen: 1,024 bits; 2nd gen: 8,192 bits; 3rd gen: 100,000+ bits
- **Connectivity:** Fully connected (all-to-all coupling)
- **Precision:** 64-bit weights
- **Performance:** ~10 billion candidate evaluations per second
- **Key innovation:** Massive parallelism with offset technique to escape local minima

#### Hitachi CMOS Annealing Machine (2015–present)

Hitachi developed a CMOS-based annealing processor:

- **Architecture:** Semiconductor-based Boltzmann machine
- **Scale:** 20,480 spins (original), scaled versions larger
- **Technology:** Standard CMOS process (no cryogenics needed)
- **Key innovation:** Uses a "momentum" term (analogous to kinetic energy) to help escape local minima

#### NTT Coherent Ising Machine (CIM) (2016–present)

A photonic implementation using optical parametric oscillators:

- **Architecture:** Optical pulse network in fiber cavity
- **Scale:** Up to 100,000 spins
- **Technology:** Coherent optical pulses represent spins
- **Key innovation:** Measurement-feedback coupling enables dense connectivity

#### Academic Research Systems

- **Purdue/Keio p-bit FPGA** (Camsari et al., 2017): Hardware p-bit networks on FPGAs, demonstrating probabilistic computing for optimization and machine learning.
- **University of Tokyo "Ising Chip"** (Yamaoka et al., 2015): 20K-spin CMOS annealing processor at 65nm, solving Max-Cut in microseconds.
- **Toshiba Simulated Bifurcation Machine** (Goto et al., 2019): Algorithm inspired by bifurcation phenomena in nonlinear oscillators, highly parallelizable on FPGAs and GPUs.

---

## 3. Quantum vs. Quantum-Inspired

### 3.1 Quantum Annealing (D-Wave)

D-Wave Systems builds quantum annealing processors using superconducting flux qubits:

- **Technology:** Niobium superconducting circuits at 15 mK
- **Mechanism:** Quantum tunneling through energy barriers via transverse field
- **Hamiltonian:** Time-dependent $H(t) = A(t)\,H_{\text{driver}} + B(t)\,H_{\text{problem}}$
- **Current scale:** 5,000+ qubits (Advantage system, Pegasus topology)
- **Connectivity:** Sparse (each qubit connects to ~15 neighbors)
- **Embedding overhead:** Dense problems require chains of physical qubits to represent single logical variables

**Advantages:**
- Quantum tunneling can potentially traverse tall, thin energy barriers
- Native physics-based computation

**Limitations:**
- Cryogenic operation (~$10M+ system cost)
- Limited connectivity requires problem embedding (wastes qubits)
- Noise and decoherence limit computation depth
- Quantum speedup remains debated for optimization

### 3.2 Digital Annealing (This Project)

Digital annealing uses **classical stochastic hardware** to achieve similar exploration of solution spaces:

- **Technology:** Standard CMOS (FPGAs, ASICs)
- **Mechanism:** Thermal fluctuations via pseudo-random noise injection
- **Hamiltonian:** Programmed directly into weight registers
- **Connectivity:** Fully programmable (any topology)
- **Operating conditions:** Room temperature, standard power

**Advantages:**
- Room temperature operation
- Full programmable connectivity (no embedding overhead)
- Deterministic debugging and replay
- Scalable via Moore's Law
- Orders of magnitude cheaper

**Limitations:**
- No quantum tunneling (relies purely on thermal fluctuations)
- May be slower for specific problem structures where tunneling dominates

### 3.3 The Key Distinction

> **This project is quantum-INSPIRED, not quantum.** It borrows the Ising model formulation and annealing algorithm from quantum computing but implements them entirely with classical probabilistic bits on conventional hardware. There are no qubits, no quantum superposition, and no quantum entanglement.

The name "quantum-inspired" reflects the algorithmic heritage, not the implementation technology. The mathematical framework (Ising Hamiltonian, Boltzmann sampling) is shared, but the physics is classical.

---

## 4. P-Bit Computing

### 4.1 What is a P-Bit?

A **probabilistic bit (p-bit)** is a classical computing element that fluctuates between 0 and 1 with a controllable bias. It occupies a conceptual space between classical bits and qubits:

| | Classical Bit | **P-Bit** | Qubit |
|---|---|---|---|
| **States** | 0 or 1 | 0 or 1 (fluctuating) | α\|0⟩ + β\|1⟩ |
| **Nature** | Deterministic | **Stochastic** | Quantum |
| **Control** | Voltage level | **Bias + noise** | Microwave pulses |
| **Measurement** | Non-destructive | **Each sample differs** | Collapses state |
| **Temperature** | Room temp | **Room temp** | ~15 mK |
| **Technology** | CMOS transistor | **CMOS + noise source** | Superconducting junction |

### 4.2 P-Bit Operation

A p-bit's output is governed by:

$$m_i = \text{sgn}\!\left(\tanh\!\left(\frac{I_i}{T}\right) + r_i\right)$$

where:
- $I_i = \sum_j J_{ij}\,m_j + h_i$ is the input from connected p-bits and external bias
- $T$ is the effective temperature (noise amplitude)
- $r_i \sim U(-1, 1)$ is a random perturbation

At low temperature, the p-bit acts deterministically (follows the sign of $I_i$). At high temperature, it behaves as a random coin flip. This tunable randomness is the key feature enabling optimization.

### 4.3 P-Bit Networks and Boltzmann Machines

When p-bits are interconnected with weights $J_{ij}$, the network naturally samples from the Boltzmann distribution of the corresponding Ising Hamiltonian. This makes p-bit networks equivalent to **Restricted Boltzmann Machines (RBMs)** and, more generally, **Boltzmann Machines** from machine learning.

Applications of p-bit networks:
- **Combinatorial optimization:** Ground state search = energy minimization
- **Probabilistic inference:** Sampling from posterior distributions
- **Generative modeling:** Learning and sampling data distributions
- **Invertible logic:** Running Boolean circuits "backwards" to find inputs from outputs

### 4.4 Hardware P-Bit Implementations

P-bits have been demonstrated in multiple technologies:

| Technology | Mechanism | Speed | Reference |
|---|---|---|---|
| **CMOS + LFSR** | Digital noise injection | ~GHz | This project |
| **Stochastic MTJ** | Magnetic tunnel junction fluctuation | ~ns | Camsari et al. (2017) |
| **Memristive** | Resistive switching noise | ~μs | Borders et al. (2019) |
| **CMOS inverter pair** | Metastable bistable circuit | ~GHz | Pervaiz et al. (2018) |

Our implementation uses the simplest approach: a digital comparator fed by an LFSR random source and a computed local field, achieving ~100 MHz update rates on FPGA.

---

## 5. Digital Annealing Systems

### 5.1 Architecture Patterns

Modern digital annealing systems share common architectural elements:

```
┌─────────────────────────────────────────────────────┐
│                 Digital Annealer                     │
│                                                     │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐    │
│  │  Weight   │   │  Spin    │   │  Temperature │    │
│  │  Memory   │──►│  Update  │◄──│  Controller  │    │
│  │  (J, h)   │   │  Engine  │   │              │    │
│  └──────────┘   └────┬─────┘   └──────────────┘    │
│                      │                               │
│                      ▼                               │
│                ┌──────────┐                          │
│                │  Energy   │                          │
│                │ Evaluator │                          │
│                └──────────┘                          │
│                                                     │
│  ┌──────────────────────────────────────────┐       │
│  │          Host Interface (PCIe/AXI)        │       │
│  └──────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

### 5.2 CMOS Advantages Over Quantum

Digital annealing on CMOS provides several practical advantages:

1. **Room Temperature Operation:** No cryogenics, no dilution refrigerators, no vacuum systems. A $100 FPGA board replaces a $10M quantum system.

2. **Scalability:** CMOS transistor counts double every ~2 years (Moore's Law). Spin counts in digital annealers can scale with available logic resources.

3. **Full Connectivity:** Unlike quantum annealers with sparse qubit graphs (Chimera, Pegasus), digital annealers can implement arbitrary coupling topologies without embedding overhead.

4. **Deterministic Debugging:** Every internal state is observable via waveform viewers, logic analyzers, and simulation. Quantum states collapse upon measurement.

5. **Precision:** Digital systems support arbitrary precision weights (16, 32, 64 bits). Quantum couplers have limited precision (~5–6 bits effective).

6. **Integration:** CMOS annealers integrate naturally with existing digital systems via PCIe, AXI, or other standard interfaces.

### 5.3 Performance Comparison

| System | Spins | Updates/sec | Connectivity | Precision |
|---|---|---|---|---|
| D-Wave Advantage | 5,000 qubits | ~10K reads/s | Pegasus (sparse) | ~5 bits |
| Fujitsu DAU (3rd gen) | 100,000+ | ~10B/s | Full | 64 bits |
| Hitachi CMOS | 20,480 | ~1B/s | Programmable | 16 bits |
| Toshiba SBM (GPU) | 100,000+ | ~100M/s | Full | 64-bit FP |
| **This project (FPGA)** | **8–64** | **~100M/s** | **Full** | **16 bits** |

> Note: Direct comparison is nuanced — different systems excel on different problem structures. Our project is a research platform, not a competitor to commercial systems.

---

## 6. FPGA Implementation Advantages

### 6.1 Why FPGAs for Digital Annealing?

FPGAs are an ideal substrate for digital annealing accelerators:

1. **Massive Parallelism:** Thousands of p-bits can operate simultaneously, each with its own RNG and coupler logic. Unlike CPUs/GPUs, there is no instruction fetch/decode overhead.

2. **Custom Datapath:** Fixed-point arithmetic, custom bit widths, and specialized accumulator structures are naturally expressed in RTL. No wasted transistors on general-purpose features.

3. **Low Latency:** Combinational evaluation of the local field enables single-cycle spin updates. No memory access latency, no cache misses.

4. **Reconfigurability:** Different problem sizes, topologies, and algorithmic variants can be loaded by re-synthesizing the design. Parameters like `NUM_SPINS` and `UPDATE_STRATEGY` are elaboration-time configurable.

5. **Deterministic Timing:** Unlike software on CPUs with caches, branch predictors, and OS interrupts, FPGA implementations have cycle-accurate deterministic behavior.

6. **Prototyping Path to ASIC:** RTL designed for FPGA is directly portable to ASIC synthesis for maximum performance and efficiency.

### 6.2 FPGA vs. GPU for Annealing

| Aspect | FPGA | GPU |
|---|---|---|
| Parallelism | Spatial (all spins in hardware) | Temporal (thread blocks) |
| Latency | 1 cycle per update | 100s of cycles (kernel launch, memory) |
| Throughput | Limited by LUT count | Limited by memory bandwidth |
| Precision | Custom (16-bit optimal) | 32/64-bit FP (wasteful) |
| Power | 5–25W | 150–350W |
| Flexibility | Requires re-synthesis | Recompile kernel |
| Best for | ≤ 10K spins, lowest latency | > 10K spins, rapid prototyping |

### 6.3 Target FPGA Families

| Family | Example Part | LUTs | BRAM | Max Spins (est.) |
|---|---|---|---|---|
| Xilinx Artix-7 | XC7A100T | 63K | 135×36Kb | 32–48 |
| Xilinx Zynq-7000 | XC7Z020 | 53K | 140×36Kb | 32 |
| Xilinx UltraScale+ | XCZU9EG | 274K | 912×36Kb | 128–192 |
| Intel Cyclone V | 5CEFA9 | 113K ALMs | 684×M10K | 48–64 |
| Intel Stratix 10 | 1SG280 | 933K ALMs | 11,721×M20K | 512+ |

---

## 7. Benchmark Problems & Ising Formulations

### 7.1 Max-Cut

**Problem:** Partition graph vertices into two sets to maximize the number of edges crossing the partition.

**Ising Formulation:**
$$E_{\text{Max-Cut}} = -\sum_{(i,j) \in \text{edges}} J_{ij}\,(1 - \sigma_i\,\sigma_j)$$

Set $J_{ij} = -w_{ij}$ (negative of edge weight) for each edge. Minimizing $E$ maximizes the cut value. Anti-aligned spins ($\sigma_i \neq \sigma_j$) contribute to the cut.

**In this project:** The integration test (`tb_qa_top`) uses a Max-Cut problem on an 8-spin ring with antiferromagnetic coupling ($J = -1000$). The optimal solution is the alternating pattern `01010101` (or `10101010`), cutting all 8 edges.

### 7.2 Graph Partitioning

**Problem:** Partition graph vertices into two equal-sized sets minimizing the number of crossing edges (opposite of Max-Cut with a balance constraint).

**Ising Formulation:**
$$E_{\text{Partition}} = -\sum_{(i,j) \in \text{edges}} J_{ij}\,\sigma_i\,\sigma_j + \lambda\left(\sum_i \sigma_i\right)^2$$

The quadratic penalty $\lambda(\sum_i \sigma_i)^2$ enforces balanced partitions. When $\lambda$ is sufficiently large, the ground state has equal numbers of $+1$ and $-1$ spins.

### 7.3 Boolean Satisfiability (SAT)

**Problem:** Find a variable assignment satisfying all clauses of a Boolean formula in conjunctive normal form (CNF).

**Ising Formulation (3-SAT):**

Each clause $(x_a \lor x_b \lor x_c)$ maps to a penalty term. For a clause with variables $\sigma_a, \sigma_b, \sigma_c$ (with appropriate sign flips for negated literals):

$$E_{\text{clause}} = \frac{1}{8}(1 - \sigma_a)(1 - \sigma_b)(1 - \sigma_c)$$

This term is zero when the clause is satisfied and positive when violated. The total energy sums over all clauses — a ground state with $E = 0$ satisfies all clauses.

### 7.4 Traveling Salesman Problem (TSP)

**Problem:** Find the shortest tour visiting all $N$ cities exactly once.

**Ising Formulation:**

Uses an $N \times N$ permutation matrix encoded as $N^2$ binary spins $x_{i,t} \in \{0,1\}$ where $x_{i,t} = 1$ means city $i$ is visited at time step $t$.

$$E_{\text{TSP}} = A\sum_i\!\left(\sum_t x_{i,t} - 1\right)^{\!2} + A\sum_t\!\left(\sum_i x_{i,t} - 1\right)^{\!2} + B\sum_t\sum_{i,j} d_{ij}\,x_{i,t}\,x_{j,t+1}$$

- **First term:** Each city visited exactly once (row constraint)
- **Second term:** Exactly one city per time step (column constraint)
- **Third term:** Minimize total distance traveled
- $A \gg B$ ensures constraint satisfaction before distance optimization

**Scaling:** TSP requires $N^2$ spins for $N$ cities, making it one of the most resource-intensive formulations.

### 7.5 Problem Mapping Summary

| Problem | Spins Needed | Coupling Density | Difficulty |
|---|---|---|---|
| Max-Cut | $N$ (nodes) | Sparse (graph edges) | Moderate |
| Graph Partition | $N$ (nodes) | Dense (edges + penalty) | Moderate |
| 3-SAT | $N$ (variables) | Sparse (clause interactions) | Hard |
| TSP | $N^2$ (city × time) | Dense (distance + constraints) | Very Hard |
| Quadratic Assignment | $N^2$ | Dense | Very Hard |
| Graph Coloring | $N \times k$ | Dense | Hard |

---

## 8. References

### Foundational Theory

1. **Ising, E.** (1925). "Beitrag zur Theorie des Ferromagnetismus." *Zeitschrift für Physik*, 31(1), 253–258. — Original Ising model paper.

2. **Kirkpatrick, S., Gelatt, C. D., & Vecchi, M. P.** (1983). "Optimization by Simulated Annealing." *Science*, 220(4598), 671–680. — Introduced simulated annealing for optimization.

3. **Metropolis, N., et al.** (1953). "Equation of State Calculations by Fast Computing Machines." *Journal of Chemical Physics*, 21(6), 1087–1092. — The Metropolis algorithm.

4. **Barahona, F.** (1982). "On the computational complexity of Ising spin glass models." *Journal of Physics A*, 15(10), 3241. — Proved Ising ground state is NP-hard.

### Quantum Annealing

5. **Kadowaki, T. & Nishimori, H.** (1998). "Quantum annealing in the transverse Ising model." *Physical Review E*, 58(5), 5355. — Theoretical foundation of quantum annealing.

6. **Johnson, M. W., et al.** (2011). "Quantum annealing with manufactured spins." *Nature*, 473, 194–198. — D-Wave's first experimental demonstration.

### Digital Annealing & CMOS Ising Machines

7. **Aramon, M., et al.** (2019). "Physics-Inspired Optimization for Quadratic Unconstrained Problems Using a Digital Annealer." *Frontiers in Physics*, 7, 48. — Fujitsu Digital Annealer architecture and benchmarks.

8. **Matsubara, S., et al.** (2020). "Digital Annealer for High-Speed Solving of Combinatorial Optimization Problems and Its Applications." *2020 25th Asia and South Pacific Design Automation Conference (ASP-DAC)*, 667–672. — Fujitsu DAU applications.

9. **Yamaoka, M., et al.** (2015). "A 20k-Spin Ising Chip to Solve Combinatorial Optimization Problems With CMOS Annealing." *IEEE Journal of Solid-State Circuits*, 51(1), 303–309. — Hitachi/University of Tokyo CMOS Ising chip.

10. **Yoshimura, C., et al.** (2017). "CMOS Annealing Machine: A Domain-Specific Architecture for Combinatorial Optimization Problem." *2017 IEEE International Conference on Rebooting Computing (ICRC)*, 1–6. — Hitachi CMOS annealing architecture.

### P-Bit Computing

11. **Camsari, K. Y., Faria, R., Sutton, B. M., & Datta, S.** (2017). "Stochastic p-bits for Invertible Logic." *Physical Review X*, 7(3), 031014. — Foundational p-bit paper.

12. **Camsari, K. Y., Sutton, B. M., & Datta, S.** (2019). "p-bits for probabilistic spin logic." *Applied Physics Reviews*, 6(1), 011305. — Comprehensive review of p-bit computing.

13. **Borders, W. A., et al.** (2019). "Integer factorization using stochastic magnetic tunnel junctions." *Nature*, 573, 390–393. — Hardware p-bit demonstration using MTJs.

14. **Pervaiz, A. Z., et al.** (2018). "Weighted p-bits for FPGA Implementation of Probabilistic Circuits." *IEEE Transactions on Neural Networks and Learning Systems*, 30(6), 1920–1926. — FPGA p-bit implementation.

### Simulated Bifurcation & Alternative Algorithms

15. **Goto, H., et al.** (2019). "Combinatorial optimization by simulating adiabatic bifurcations in nonlinear Hamiltonian systems." *Science Advances*, 5(4), eaav2372. — Toshiba's simulated bifurcation machine.

16. **Goto, H., et al.** (2021). "High-performance combinatorial optimization based on classical mechanics." *Science Advances*, 7(6), eabe7953. — Ballistic simulated bifurcation.

### FPGA-Based Optimization Accelerators

17. **Tsukamoto, S., et al.** (2017). "An Accelerator Architecture for Combinatorial Optimization Problems." *Fujitsu Scientific & Technical Journal*, 53(5), 8–13. — FPGA-accelerated annealing.

18. **Cook, C., et al.** (2019). "GPU-Based Ising Computing for Solving Max-Cut Combinatorial Optimization Problems." *Integration*, 69, 335–344. — GPU comparison point.

---

<div align="center">
<sub>See also: <a href="DESIGN.md">DESIGN.md</a> for implementation design · <a href="ARCHITECTURE.md">ARCHITECTURE.md</a> for module-level architecture</sub>
</div>
