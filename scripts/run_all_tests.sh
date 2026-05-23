#!/bin/bash
# ==============================================================================
# Run all RTL testbenches
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$SCRIPT_DIR/../sim"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Quantum-Inspired Optimization Accelerator              ║"
echo "║  Running All RTL Testbenches                            ║"
echo "╚══════════════════════════════════════════════════════════╝"

cd "$SIM_DIR"

TESTS=(
    "tb_rng_module"
    "tb_spin_cell"
    "tb_ising_coupler"
    "tb_anneal_controller"
    "tb_energy_tracker"
    "tb_qa_top"
)

PASSED=0
FAILED=0

for test in "${TESTS[@]}"; do
    echo ""
    echo "━━━ Running: $test ━━━"
    if make "$test" 2>&1; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        echo "FAILED: $test"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASSED passed, $FAILED failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
