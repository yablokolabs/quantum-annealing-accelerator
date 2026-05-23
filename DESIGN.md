# Design Document

> Theoretical foundations, algorithmic design, and hardware implementation decisions for the Quantum-Inspired Optimization Accelerator.

---

## Table of Contents

1. [Ising Model Theory](#1-ising-model-theory)
2. [Simulated Annealing](#2-simulated-annealing)
3. [Stochastic Computing & P-Bits](#3-stochastic-computing--p-bits)
4. [Hardware Approximations](#4-hardware-approximations)
5. [Cooling Strategies](#5-cooling-strategies)
6. [Update Strategies](#6-update-strategies)
7. [Fixed-Point Arithmetic](#7-fixed-point-arithmetic)
8. [Verification Strategy](#8-verification-strategy)
9. [Design Decisions & Trade-offs](#9-design-decisions--trade-offs)

---

## 1. Ising Model Theory

### 1.1 The Ising Hamiltonian

The Ising model is a mathematical framework from statistical mechanics that describes interacting binary variables (spins) on a graph. The energy (Hamiltonian) of a spin configuration is:

$$E(\boldsymbol{\sigma}) = -\sum_{i<j} J_{ij}\,\sigma_i\,\sigma_j \;-\; \sum_i h_i\,\sigma_i$$

where:
- $\sigma_i \in \lbrace -1, +1 \rbrace$ — spin state of the $i$-th variable
- $J_{ij} \in \mathbb{R}$ — coupling weight between spins $i$ and $j$
- $h_i \in \mathbb{R}$ — external bias (local field) on spin $i$

The first term encodes pairwise interactions: when $J_{ij} > 0$, spins $i$ and $j$ prefer to align (ferromagnetic); when $J_{ij} < 0$, they prefer to anti-align (antiferromagnetic). The second term biases individual spins.

### 1.2 Spin States and Encoding

In our hardware implementation, spins are stored as single bits:

| Hardware Bit | Ising Spin |
|---|---|
| `0` | $-1$ |
| `1` | $+1$ |

The conversion is: $\sigma = 2b - 1$ where $b \in \lbrace 0, 1 \rbrace$.

### 1.3 Energy Landscapes

The set of all $2^N$ spin configurations defines an **energy landscape**. Finding the global minimum of this landscape is equivalent to solving the encoded optimization problem. For most non-trivial problems, this landscape is **rugged** — containing many local minima separated by energy barriers — making exhaustive search intractable for large $N$.

### 1.4 QUBO Equivalence

The Ising model is mathematically equivalent to **Quadratic Unconstrained Binary Optimization (QUBO)**:

$$\min_{\mathbf{x}} \; \mathbf{x}^T Q \mathbf{x}, \qquad x_i \in \lbrace 0, 1 \rbrace$$

The transformation between QUBO variables $x_i$ and Ising spins $\sigma_i$ is: $x_i = (\sigma_i + 1) / 2$. Any QUBO problem can be mapped to an Ising Hamiltonian and vice versa, making the Ising model a universal representation for combinatorial optimization.

---

## 2. Simulated Annealing

### 2.1 Metropolis-Hastings Algorithm

Simulated annealing uses the Metropolis-Hastings algorithm to stochastically explore the energy landscape:

1. **Propose** a spin flip: select spin $i$, compute $\Delta E = E(\sigma_i \to -\sigma_i) - E(\boldsymbol{\sigma})$
2. **Accept** the flip with probability:

$$P(\text{accept}) = \min\!\left(1,\; \exp\!\left(-\frac{\Delta E}{T}\right)\right)$$

3. **Cool**: reduce temperature $T$ according to a cooling schedule.

At high temperature, most moves are accepted (exploration). As $T \to 0$, only energy-lowering moves are accepted (exploitation). This mimics the physical annealing process of slowly cooling a material to find its crystalline ground state.

### 2.2 Energy Delta Computation

For a single spin flip of $\sigma_i$, the energy change is efficiently computed as:

$$\Delta E_i = 2\,\sigma_i \left(\sum_j J_{ij}\,\sigma_j + h_i\right) = 2\,\sigma_i \cdot h_{\text{eff},i}$$

where $h_{\text{eff},i} = \sum_j J_{ij}\,\sigma_j + h_i$ is the **effective local field** at spin $i$. This is an $O(N)$ computation per spin flip, compared to $O(N^2)$ for full Hamiltonian re-evaluation.

### 2.3 Boltzmann Distribution

At thermal equilibrium at temperature $T$, the probability of a configuration follows the Boltzmann distribution:

$$P(\boldsymbol{\sigma}) = \frac{1}{Z}\exp\!\left(-\frac{E(\boldsymbol{\sigma})}{T}\right), \qquad Z = \sum_{\boldsymbol{\sigma}} \exp\!\left(-\frac{E(\boldsymbol{\sigma})}{T}\right)$$

The Metropolis-Hastings algorithm is guaranteed to converge to this distribution given sufficient time at each temperature, ensuring ergodic exploration.

### 2.4 Acceptance Criterion in Hardware

Rather than computing $\exp(-\Delta E / T)$ explicitly, we compare a random number $r \sim U(0,1)$ against the acceptance threshold. In hardware, this becomes a comparison between the random value from the RNG and a threshold derived from $\Delta E$ and $T$ (see [Section 4: Hardware Approximations](#4-hardware-approximations)).

---

## 3. Stochastic Computing & P-Bits

### 3.1 Probabilistic Bits (P-Bits)

A **p-bit** (probabilistic bit) is a classical computing element that fluctuates between 0 and 1 with a controllable probability. Unlike a deterministic bit (always 0 or 1) or a qubit (quantum superposition), a p-bit is a classical stochastic unit described by:

$$m_i = \text{sgn}\!\left(\tanh\!\left(\frac{h_{\text{eff},i}}{T}\right) - r_i\right)$$

where $r_i \sim U(-1, 1)$ is a random number and $T$ controls the noise level. At $T \to 0$, the p-bit becomes deterministic; at $T \to \infty$, it becomes a fair coin.

### 3.2 P-Bit Networks as Boltzmann Machines

An interconnected network of p-bits, with coupling weights $J_{ij}$ and biases $h_i$, naturally samples from the Boltzmann distribution of the corresponding Ising Hamiltonian. This makes p-bit hardware a natural substrate for:

- **Combinatorial optimization** (find the ground state)
- **Probabilistic inference** (sample from posterior distributions)
- **Boltzmann machine learning** (train generative models)

### 3.3 Connection to Quantum Annealing

Quantum annealers (e.g., D-Wave) use quantum tunneling to escape local minima. Digital annealing with p-bits achieves a similar effect through thermal fluctuations — controlled noise that allows the system to explore beyond local minima. While quantum tunneling can theoretically traverse tall, thin energy barriers more efficiently, thermal fluctuations are effective for a wide class of practical problems and are implementable on standard CMOS hardware.

---

## 4. Hardware Approximations

### 4.1 Linearized Sigmoid

The true Metropolis acceptance function requires computing $\tanh(h_{\text{eff}} / T)$ or $\exp(-\Delta E / T)$, both of which are expensive in hardware. Our `spin_cell` module uses a **hardware-linearized approximation**:

```
threshold = local_field + noise_term
new_spin  = (threshold > 0) ? 1 : 0
```

The `noise_term` is derived from the RNG output scaled by temperature. At high temperature, noise dominates (random exploration); at low temperature, the local field dominates (deterministic convergence). This linear approximation:

- Eliminates the need for lookup tables or CORDIC units
- Requires only an adder and comparator in the critical path
- Preserves the essential exploration-exploitation trade-off
- Matches the qualitative behavior of the true sigmoid within the operating range

### 4.2 LFSR-Based Pseudo-Random Numbers

True random number generation (TRNG) is expensive in hardware. We use **Galois LFSR** (Linear Feedback Shift Register) with the polynomial $x^{16} + x^{14} + x^{13} + x^{11} + 1$ for a maximal-length sequence of $2^{16} - 1$ states. Properties:

- **1 XOR gate + 1 shift register** — minimal area
- **1 cycle latency** — new random value every clock
- **Deterministic** — identical seed produces identical sequence, enabling reproducible simulation
- **Sufficient quality** — LFSR sequences pass basic randomness tests for optimization purposes

An alternative **xorshift** mode (`RNG_XORSHIFT`) provides better statistical properties at slightly higher logic cost (3 shift + 3 XOR operations per cycle).

### 4.3 Fixed-Point Arithmetic

All arithmetic uses **16-bit unsigned fixed-point** (Q0.16 format) for temperature and probability values, and **16-bit signed fixed-point** for weights, biases, and energy deltas:

| Quantity | Format | Range |
|---|---|---|
| Temperature | Q0.16 unsigned | $[0, 1 - 2^{-16}]$ mapped to logical range |
| Weights $J_{ij}$ | Q1.15 signed | $[-1, +1 - 2^{-15}]$ |
| Biases $h_i$ | Q1.15 signed | $[-1, +1 - 2^{-15}]$ |
| Local field | Signed, extended | Guard bits for accumulation |
| Energy | 2×DATA_WIDTH signed | Full precision for Hamiltonian |

Fixed-point multiplication is implemented in `qa_pkg::fp_multiply()`:

```systemverilog
function automatic logic [DATA_WIDTH-1:0] fp_multiply(
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b
);
    logic [2*DATA_WIDTH-1:0] full_product;
    full_product = a * b;
    return full_product[2*DATA_WIDTH-1:DATA_WIDTH];  // Upper half
endfunction
```

### 4.4 Local Field Accumulation

The `ising_coupler` computes $h_{\text{eff},i} = \sum_j J_{ij}\sigma_j + h_i$ using a combinational accumulation loop with guard bits to prevent overflow:

- Accumulator width: `DATA_WIDTH + $clog2(NUM_SPINS) + 1` bits
- Spin encoding: hardware bit `1` → adds $J_{ij}$, bit `0` → subtracts $J_{ij}$
- Bias added after the coupling sum
- Optional pipeline register (`PIPELINED=1`) for timing closure at large `NUM_SPINS`

---

## 5. Cooling Strategies

The cooling schedule determines how temperature decreases over the annealing process. It critically affects solution quality vs. convergence speed.

### 5.1 Linear Cooling

$$T_{n+1} = T_n - \Delta T$$

The simplest schedule. Temperature decreases by a constant amount each step. Fast convergence but risks getting trapped in local minima if the rate is too aggressive.

**Implementation:** Single subtraction per temperature step.

**When to use:** Simple problems, fast prototyping, when solution quality is less critical than speed.

### 5.2 Exponential Cooling

$$T_{n+1} = T_n \cdot \alpha, \qquad \alpha = 1 - \text{cool\_rate} \approx 0.95\text{--}0.999$$

Temperature decays geometrically. Spends more time at lower temperatures where fine-tuning occurs. Theoretical guarantees exist for convergence to the global optimum as $\alpha \to 1$ (infinitely slow cooling).

**Implementation:** Fixed-point multiply via `fp_multiply()`, where $\alpha$ = `0xFFFF - cool_rate`.

**When to use:** General-purpose optimization, when solution quality matters.

### 5.3 Adaptive Cooling

The controller monitors the energy trajectory and adjusts the cooling rate dynamically:

- If energy has not improved for `STAGNATION_WINDOW` (10) consecutive temperature steps → **double** the cooling rate (system is stuck, cool faster to escape)
- Otherwise, cooling continues at the current rate

**Implementation:** Counter tracks cycles since last energy improvement. Stagnation detection triggers rate adjustment.

**When to use:** Unknown problem difficulty, auto-tuning scenarios, when manual schedule tuning is impractical.

### 5.4 Schedule Selection

The cooling schedule is selected at elaboration time via the `SCHEDULE_TYPE` parameter or at runtime via the `config_schedule` register:

| Value | Enum | Schedule |
|---|---|---|
| `2'b00` | `SCHEDULE_LINEAR` | Linear |
| `2'b01` | `SCHEDULE_EXPONENTIAL` | Exponential |
| `2'b10` | `SCHEDULE_ADAPTIVE` | Adaptive |

---

## 6. Update Strategies

The update strategy determines which spins are updated each cycle and affects both correctness and throughput.

### 6.1 Sequential Updates

One spin is updated per clock cycle, cycling through all $N$ spins. This is the simplest and most correct approach — each spin sees the most up-to-date state of all other spins.

- **Throughput:** 1 spin/cycle → $N$ cycles per full sweep
- **Conflicts:** None
- **Quality:** Best solution quality (detailed balance maintained)

### 6.2 Checkerboard Updates

For lattice-structured problems, spins can be partitioned into two independent sets (like black and white squares on a checkerboard). All spins in one set are updated simultaneously, then the other set. This exploits the bipartite structure of many problem graphs.

- **Throughput:** $N/2$ spins/cycle → 2 cycles per full sweep
- **Conflicts:** None (by construction — no two updated spins are coupled)
- **Quality:** Maintains detailed balance within each phase
- **Controlled by:** `checkerboard_phase` signal from `anneal_controller`

### 6.3 Parallel Updates

All $N$ spins are updated simultaneously every cycle. This maximizes throughput but introduces **update conflicts** — a spin may make its decision based on stale neighbor states.

- **Throughput:** $N$ spins/cycle → 1 cycle per full sweep
- **Conflicts:** Possible (spins read stale states)
- **Quality:** May deviate from true Boltzmann sampling, but empirically works well for many problems
- **Trade-off:** Maximum speed at the cost of theoretical guarantees

### 6.4 Strategy Selection

Selected via the `UPDATE_STRATEGY` parameter:

| Value | Enum | Strategy |
|---|---|---|
| `2'b00` | `UPDATE_SEQUENTIAL` | Sequential |
| `2'b01` | `UPDATE_CHECKERBOARD` | Checkerboard |
| `2'b10` | `UPDATE_PARALLEL` | Parallel (default) |

---

## 7. Fixed-Point Arithmetic

### 7.1 Number Representation

The design uses 16-bit fixed-point throughout (`DATA_WIDTH=16` default). The `qa_pkg` package defines the multiplication function used for exponential cooling:

```
fp_multiply(a, b):
    product = a * b           // 32-bit intermediate
    return product[31:16]     // Q0.16 × Q0.16 → Q0.16 (upper half)
```

### 7.2 Precision Analysis

With 16-bit fixed-point:
- **Temperature resolution:** $2^{-16} \approx 1.5 \times 10^{-5}$
- **Weight resolution:** $2^{-15} \approx 3.1 \times 10^{-5}$ (signed)
- **Energy precision:** 32-bit accumulator supports up to $2^{15}$ spin-weight products without overflow

For most optimization problems with $N \leq 64$ spins, 16-bit precision is more than sufficient. The design is parameterized so `DATA_WIDTH` can be increased to 32 for higher-precision applications.

### 7.3 Overflow Protection

- **Local field accumulator:** Extended by `$clog2(NUM_SPINS) + 1` guard bits
- **Energy computation:** Uses `2 * DATA_WIDTH` bits for the full Hamiltonian
- **Temperature subtraction:** Saturates at zero (no underflow)

---

## 8. Verification Strategy

### 8.1 Testbench Architecture

Each module has a dedicated directed testbench (`tb/tb_<module>.sv`) that verifies:

| Testbench | Key Test Scenarios |
|---|---|
| `tb_spin_cell` | Reset state, deterministic fields, stochastic behavior (100 trials), enable gating |
| `tb_rng_module` | Initial state = seed, uniqueness, enable gating, seed reload, deterministic replay |
| `tb_ising_coupler` | Zero weights, uniform spins, mixed spins, negative weights, bias-only |
| `tb_anneal_controller` | Idle→busy transition, monotonic cooling, completion, return to idle |
| `tb_energy_tracker` | Antiferromagnetic ring energy, best tracking, convergence detection, clear |
| `tb_qa_top` | **Integration:** Max-Cut on 8-spin ring via host interface, weight loading, completion |

### 8.2 Verification Methodology

- **Directed tests:** Hand-crafted stimulus with known expected results
- **Self-checking:** `$display` + `$fatal` on assertion failure
- **Integration test:** `tb_qa_top` exercises the full host-write → configure → anneal → read-result path
- **Lint verification:** Verilator `-Wall` catches width mismatches, unused signals, missing defaults

### 8.3 Assertions

RTL modules include SystemVerilog assertions for design invariants:
- `rng_module`: Asserts LFSR state is never all-zeros (lockup protection)
- `spin_cell`: Asserts `DATA_WIDTH >= 8` (minimum precision requirement)
- `anneal_controller`: Asserts temperature is monotonically non-increasing during annealing

### 8.4 Python Digital Twin

The Python simulator in `backend/simulator/` serves as a **golden model** for RTL verification:
- Identical algorithmic behavior (Metropolis-Hastings, same cooling schedules)
- Results can be compared against RTL simulation for functional equivalence
- Faster iteration for algorithm exploration before committing to RTL changes

---

## 9. Design Decisions & Trade-offs

### 9.1 Why Fixed-Point Over Floating-Point?

**Decision:** 16-bit fixed-point arithmetic throughout.

**Rationale:**
- 10–50× less area than IEEE 754 floating-point units
- Deterministic timing (no variable-latency operations)
- Sufficient precision for optimization (weights are typically quantized anyway)
- FPGA-friendly (maps to DSP slices efficiently)

**Trade-off:** Reduced dynamic range. Mitigated by careful scaling and guard bits.

### 9.2 Why Combinational Local Field Computation?

**Decision:** The `ising_coupler` computes the local field combinationally (with optional pipeline register).

**Rationale:**
- Minimizes latency for small spin counts ($N \leq 16$)
- Single-cycle update enables maximum throughput
- Auto-pipelining when `NUM_SPINS > 16` addresses timing at scale

**Trade-off:** Combinational depth grows as $O(N)$. For very large $N$, a sequential accumulator or tree reduction would be needed.

### 9.3 Why Parallel Update as Default?

**Decision:** `UPDATE_PARALLEL` is the default update strategy.

**Rationale:**
- Maximum throughput ($N$ spins per cycle)
- Empirically effective for most benchmark problems
- Matches the inherent parallelism of hardware
- Simulates the behavior of physical Ising machines (all spins evolve simultaneously)

**Trade-off:** Violates detailed balance; may not converge to true Boltzmann distribution. Sequential mode is available when theoretical guarantees are needed.

### 9.4 Why LFSR Over True Random?

**Decision:** Galois LFSR as the default random source.

**Rationale:**
- 1 LUT + 1 FF per bit — minimal area
- Deterministic replay for debugging and verification
- Maximal-length sequence ($2^{16}-1$) provides sufficient randomness
- Xorshift alternative available for better statistical properties

**Trade-off:** Pseudo-random sequences have correlations that can theoretically bias the optimizer. Not observed in practice for $N \leq 64$.

---

<div align="center">
<sub>See also: <a href="ARCHITECTURE.md">ARCHITECTURE.md</a> for module-level design details · <a href="HARDWARE_THEORY.md">HARDWARE_THEORY.md</a> for theoretical background</sub>
</div>
