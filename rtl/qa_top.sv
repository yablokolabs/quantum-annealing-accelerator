// =============================================================================
// QA Top — Quantum-Inspired Annealing Accelerator Top-Level
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Top-level integration of the stochastic Ising machine accelerator.
//
// Architecture:
//   ┌──────────────────────────────────────────────┐
//   │  qa_top                                      │
//   │                                              │
//   │  ┌─────────────┐    ┌──────────────────┐     │
//   │  │   config     │───▶  anneal_controller│     │
//   │  │  registers   │    └───────┬──────────┘     │
//   │  └─────┬───────┘            │                │
//   │        │              temp, tick, phase       │
//   │        │weights,bias        │                │
//   │        ▼                    ▼                │
//   │  ┌──────────────────────────────────┐        │
//   │  │         spin_array               │        │
//   │  │  ┌─────┐ ┌─────┐ ... ┌─────┐    │        │
//   │  │  │spin │ │spin │     │spin │    │        │
//   │  │  │cell │ │cell │     │cell │    │        │
//   │  │  │+rng │ │+rng │     │+rng │    │        │
//   │  │  │+coup│ │+coup│     │+coup│    │        │
//   │  │  └─────┘ └─────┘     └─────┘    │        │
//   │  └───────────────┬──────────────────┘        │
//   │                  │ spins                     │
//   │                  ▼                           │
//   │  ┌──────────────────────────────────┐        │
//   │  │        energy_tracker            │        │
//   │  │  Hamiltonian, best, convergence  │        │
//   │  └──────────────────────────────────┘        │
//   └──────────────────────────────────────────────┘
//
// Parameters:
//   NUM_SPINS  — number of p-bits (default 8, scalable to 64+)
//   DATA_WIDTH — fixed-point precision (default 16)
// =============================================================================

module qa_top #(
    parameter int NUM_SPINS       = 8,
    parameter int DATA_WIDTH      = 16,
    parameter int UPDATE_STRATEGY = 2,   // 0=SEQ, 1=CHECKERBOARD, 2=PARALLEL
    parameter int SCHEDULE_TYPE   = 0,   // 0=LINEAR, 1=EXP, 2=ADAPTIVE
    parameter int INITIAL_TEMP    = 32'h7FFF,
    parameter int COOLING_RATE    = 32'h0100,
    parameter int STEPS_PER_TEMP  = 256
)(
    input  logic        clk,
    input  logic        rst_n,

    // Host interface
    input  logic        host_wr_en,
    input  logic        host_rd_en,
    input  logic [11:0] host_addr,
    input  logic [31:0] host_wr_data,
    output logic [31:0] host_rd_data,
    output logic        host_rd_valid,

    // Direct status outputs
    output logic [NUM_SPINS-1:0]         final_spins,
    output logic                         done,
    output logic                         busy,
    output logic                         converged,
    output logic [DATA_WIDTH-1:0]        current_temp,
    output logic signed [2*DATA_WIDTH-1:0] best_energy
);

    // Internal interconnect
    logic                          ctrl_start;
    logic                          ctrl_clear;
    logic                          ctrl_busy;
    logic                          ctrl_done;
    logic [DATA_WIDTH-1:0]         ctrl_temperature;
    logic                          ctrl_update_tick;
    logic                          ctrl_cb_phase;

    logic                          cfg_config_valid;
    logic [DATA_WIDTH-1:0]         cfg_init_temp;
    logic [DATA_WIDTH-1:0]         cfg_cool_rate;
    logic [1:0]                    cfg_schedule;

    logic [DATA_WIDTH*NUM_SPINS*NUM_SPINS-1:0] weight_matrix;
    logic signed [DATA_WIDTH-1:0]              bias_vec [NUM_SPINS];

    logic [NUM_SPINS-1:0]                      current_spins;

    logic signed [2*DATA_WIDTH-1:0]            track_current_energy;
    logic signed [2*DATA_WIDTH-1:0]            track_best_energy;
    logic [NUM_SPINS-1:0]                      track_best_spins;
    logic                                      track_converged;

    // -----------------------------------------------------------------------
    // Configuration Registers
    // -----------------------------------------------------------------------
    config_registers #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_config (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(host_wr_en),
        .rd_en(host_rd_en),
        .addr(host_addr),
        .wr_data(host_wr_data),
        .rd_data(host_rd_data),
        .rd_valid(host_rd_valid),
        .accel_busy(ctrl_busy),
        .accel_done(ctrl_done),
        .accel_converged(track_converged),
        .best_energy_in(track_best_energy),
        .best_spins_in(track_best_spins),
        .start(ctrl_start),
        .clear(ctrl_clear),
        .init_temp(cfg_init_temp),
        .cool_rate(cfg_cool_rate),
        .schedule_type(cfg_schedule),
        .steps_per_temp(/* unused */),
        .config_valid(cfg_config_valid),
        .weight_matrix_packed(weight_matrix),
        .bias_vector(bias_vec)
    );

    // -----------------------------------------------------------------------
    // Annealing Controller
    // -----------------------------------------------------------------------
    anneal_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .INITIAL_TEMP(INITIAL_TEMP),
        .COOLING_RATE(COOLING_RATE),
        .STEPS_PER_TEMP(STEPS_PER_TEMP),
        .SCHEDULE_TYPE(SCHEDULE_TYPE)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(ctrl_start),
        .current_energy(track_current_energy[DATA_WIDTH-1:0]),
        .config_valid(cfg_config_valid),
        .config_init_temp(cfg_init_temp),
        .config_cool_rate(cfg_cool_rate),
        .config_schedule(cfg_schedule),
        .busy(ctrl_busy),
        .done(ctrl_done),
        .temperature(ctrl_temperature),
        .update_tick(ctrl_update_tick),
        .checkerboard_phase(ctrl_cb_phase)
    );

    // -----------------------------------------------------------------------
    // Spin Array
    // -----------------------------------------------------------------------
    spin_array #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH),
        .UPDATE_STRATEGY(UPDATE_STRATEGY)
    ) u_spin_array (
        .clk(clk),
        .rst_n(rst_n),
        .update_tick(ctrl_update_tick),
        .checkerboard_phase(ctrl_cb_phase),
        .temperature(ctrl_temperature),
        .weight_matrix_packed(weight_matrix),
        .bias_vector(bias_vec),
        .spins(current_spins),
        .energy_deltas(/* used for debug only */)
    );

    // -----------------------------------------------------------------------
    // Energy Tracker
    // -----------------------------------------------------------------------
    energy_tracker #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_energy (
        .clk(clk),
        .rst_n(rst_n),
        .enable(ctrl_update_tick),
        .clear(ctrl_clear),
        .spins(current_spins),
        .weight_matrix_packed(weight_matrix),
        .bias_vector(bias_vec),
        .current_energy(track_current_energy),
        .best_energy(track_best_energy),
        .best_spins(track_best_spins),
        .converged(track_converged)
    );

    // -----------------------------------------------------------------------
    // Output assignments
    // -----------------------------------------------------------------------
    assign final_spins   = track_best_spins;
    assign done          = ctrl_done;
    assign busy          = ctrl_busy;
    assign converged     = track_converged;
    assign current_temp  = ctrl_temperature;
    assign best_energy   = track_best_energy;

endmodule
