# Contributing to Quantum-Inspired Optimization Accelerator

Thank you for your interest in contributing! This document provides guidelines and conventions for contributing to the project.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

---

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/quantum-annealing-accelerator.git
   cd quantum-annealing-accelerator
   ```
3. **Install dependencies:**
   ```bash
   make backend-install    # Python dependencies
   make frontend-install   # Node.js dependencies
   ```
4. **Verify your environment** by running the full test suite:
   ```bash
   make rtl-lint           # Verilator lint (requires Verilator ≥ 5.0)
   make rtl-sim            # RTL testbenches
   make backend-test       # Python tests
   ```

## Development Workflow

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. **Make your changes** with clear, atomic commits.
3. **Test thoroughly** before pushing (see [Testing Requirements](#testing-requirements)).
4. **Push** your branch and open a pull request.

### Branch Naming

| Prefix | Purpose | Example |
|---|---|---|
| `feature/` | New functionality | `feature/parallel-tempering` |
| `fix/` | Bug fixes | `fix/energy-tracker-overflow` |
| `refactor/` | Code restructuring | `refactor/coupler-pipeline` |
| `docs/` | Documentation only | `docs/architecture-update` |
| `test/` | Test additions/changes | `test/rng-coverage` |

---

## Code Standards

### SystemVerilog (RTL)

- **Target standard:** IEEE 1800-2017
- **Lint tool:** Verilator with `-Wall` (must pass with zero warnings)
- **Naming conventions:**
  - Modules: `snake_case` (e.g., `spin_cell`, `ising_coupler`)
  - Parameters: `UPPER_SNAKE_CASE` (e.g., `NUM_SPINS`, `DATA_WIDTH`)
  - Signals: `snake_case` (e.g., `local_field`, `update_tick`)
  - Active-low signals: `_n` suffix (e.g., `rst_n`)
  - Clock signals: `clk` prefix (e.g., `clk`, `clk_div2`)
- **Design rules:**
  - Synchronous design with single clock domain
  - Active-low asynchronous reset (`rst_n`)
  - No latches — use explicit `default` in all `case` statements
  - Parameterize everything — avoid magic numbers
  - Use `logic` instead of `reg`/`wire` where possible
  - Include `$clog2()` for bus width computation
  - Add `// synth: ...` comments for synthesis-critical decisions
- **File structure:**
  ```systemverilog
  // Module: module_name
  // Description: Brief one-line description
  // Author: Your Name
  //
  // Details about the module design...

  module module_name #(
      parameter int PARAM_A = 8,
      parameter int PARAM_B = 16
  ) (
      input  logic        clk,
      input  logic        rst_n,
      // ... grouped by function with comments
      output logic [7:0]  result
  );
      // Implementation
  endmodule
  ```

### Python (Backend)

- **Version:** Python 3.11+
- **Type annotations:** Required on all function signatures
- **Formatter:** Use consistent formatting (recommend `ruff format`)
- **Linter:** `ruff` and `mypy` must pass
- **Style:**
  - Use Pydantic models for all API request/response schemas
  - Use `async def` for all API endpoint handlers
  - Docstrings on all public functions (Google style)
  - Use `pathlib.Path` over `os.path`
- **Example:**
  ```python
  async def compute_energy(
      spins: np.ndarray,
      weights: np.ndarray,
      biases: np.ndarray,
  ) -> float:
      """Compute the Ising Hamiltonian energy for a spin configuration.

      Args:
          spins: Array of spin values in {-1, +1}.
          weights: Symmetric coupling matrix J_ij.
          biases: Local bias vector h_i.

      Returns:
          Total energy E = -Σ J_ij σ_i σ_j - Σ h_i σ_i.
      """
      ...
  ```

### React/TypeScript (Frontend)

- **Framework:** React 18+ with TypeScript strict mode
- **Components:** Functional components with hooks
- **State management:** React hooks (`useState`, `useReducer`, `useContext`)
- **Styling:** Follow the design tokens in `DESIGN_PHILOSOPHY.md`
- **Naming:**
  - Components: `PascalCase` (e.g., `SpinGrid`, `EnergyPlot`)
  - Hooks: `camelCase` with `use` prefix (e.g., `useSimulation`)
  - Files: Match component name (e.g., `SpinGrid.tsx`)

---

## Testing Requirements

### RTL Changes

All RTL modifications must satisfy:

1. **Lint clean:** `make rtl-lint` passes with zero warnings
2. **Existing tests pass:** `make rtl-sim` — all 6 testbenches pass
3. **New tests:** Any new module requires a corresponding testbench in `tb/`
4. **Test coverage goals:**
   - Reset behavior
   - Normal operation (happy path)
   - Edge cases and boundary conditions
   - Parameter variations (if applicable)

### Backend Changes

1. **Unit tests:** `make backend-test` passes
2. **Type checking:** `mypy` clean
3. **Linting:** `ruff` clean
4. **New endpoints:** Include corresponding test cases

### Frontend Changes

1. **Type checking:** `tsc --noEmit` passes
2. **Linting:** ESLint clean
3. **Build:** `npm run build` succeeds

---

## Pull Request Process

1. **Fill out the PR description** with:
   - Summary of changes
   - Motivation and context
   - Testing performed
   - Related issues (use `Closes #N` to auto-close)

2. **Ensure all CI checks pass** (RTL lint, backend tests, frontend build).

3. **Keep PRs focused** — one feature or fix per PR. Large changes should be split into a series of smaller, reviewable PRs.

4. **Respond to review feedback** promptly.

5. **Squash commits** before merge if the PR has many small fixup commits.

### PR Checklist

```markdown
- [ ] Code follows the project's style guidelines
- [ ] Self-review of code completed
- [ ] Tests added/updated for new functionality
- [ ] All existing tests pass
- [ ] Documentation updated (if applicable)
- [ ] No new Verilator lint warnings introduced
```

---

## Issue Guidelines

### Bug Reports

Include:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Verilator version, Python version)
- Relevant log output or waveform screenshots

### Feature Requests

Include:
- Description of the desired feature
- Motivation and use case
- Proposed approach (if any)
- Impact on existing modules

---

## Questions?

Open a [Discussion](https://github.com/yablokolabs/quantum-annealing-accelerator/discussions) for questions about the architecture, design decisions, or implementation approaches.

---

<div align="center">
<sub>Thank you for helping improve the Quantum-Inspired Optimization Accelerator!</sub>
</div>
