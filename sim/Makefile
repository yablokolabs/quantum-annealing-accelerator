# ==============================================================================
# Quantum-Inspired Optimization Accelerator — Simulation Makefile
# Copyright (c) 2024 Yabloko Labs. All rights reserved.
# ==============================================================================

VERILATOR      ?= verilator
VERILATOR_ROOT ?= $(HOME)/.local/share/verilator
export VERILATOR_ROOT

RTL_DIR  := ../rtl
TB_DIR   := ../tb
VCD_DIR  := .

# RTL source files (order matters for package)
RTL_SRCS := \
    $(RTL_DIR)/qa_pkg.sv \
    $(RTL_DIR)/rng_module.sv \
    $(RTL_DIR)/spin_cell.sv \
    $(RTL_DIR)/ising_coupler.sv \
    $(RTL_DIR)/anneal_controller.sv \
    $(RTL_DIR)/energy_tracker.sv \
    $(RTL_DIR)/spin_array.sv \
    $(RTL_DIR)/config_registers.sv \
    $(RTL_DIR)/qa_top.sv

# Testbench targets
TB_TARGETS := tb_rng_module tb_spin_cell tb_ising_coupler tb_anneal_controller tb_energy_tracker tb_qa_top

LINT_FLAGS := --lint-only -Wall -Wno-UNUSEDPARAM -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY

.PHONY: all lint sim clean waves help $(TB_TARGETS)

all: lint sim

help:
	@echo "Targets:"
	@echo "  lint              — Run Verilator lint on all RTL"
	@echo "  sim               — Run all testbenches (requires iverilog)"
	@echo "  tb_rng_module     — Run RNG testbench"
	@echo "  tb_spin_cell      — Run spin cell testbench"
	@echo "  tb_ising_coupler  — Run coupler testbench"
	@echo "  tb_anneal_controller — Run controller testbench"
	@echo "  tb_energy_tracker — Run energy tracker testbench"
	@echo "  tb_qa_top         — Run top-level integration test"
	@echo "  clean             — Remove build artifacts"

# Verilator lint
lint:
	@echo "=== Verilator Lint ==="
	$(VERILATOR) $(LINT_FLAGS) --top-module qa_top $(RTL_SRCS)
	@echo "=== Lint PASSED ==="

# Individual testbench targets (using Verilator C++ simulation)
define VERILATOR_SIM_RULE
$(1): $(RTL_SRCS) $(TB_DIR)/$(1).sv
	@echo "=== Simulating $(1) ==="
	@mkdir -p obj_$(1)
	$(VERILATOR) --binary --timing -j 0 \
		--top-module $(1) \
		-Wno-UNUSEDPARAM -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-TIMESCALEMOD \
		--Mdir obj_$(1) \
		-o V$(1) \
		$(RTL_SRCS) $(TB_DIR)/$(1).sv
	./obj_$(1)/V$(1)
	@echo "=== $(1) COMPLETE ==="
endef

$(foreach tb,$(TB_TARGETS),$(eval $(call VERILATOR_SIM_RULE,$(tb))))

# Run all simulations
sim: $(TB_TARGETS)
	@echo "=== ALL SIMULATIONS PASSED ==="

# Clean
clean:
	rm -rf obj_* *.vcd
