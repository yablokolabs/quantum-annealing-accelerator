// =============================================================================
// Quantum-Inspired Optimization Accelerator — Package Definitions
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Shared types, constants, and utility functions used across all RTL modules.
// =============================================================================

package qa_pkg;

  // -------------------------------------------------------------------------
  // Data width configurations
  // -------------------------------------------------------------------------
  parameter int DEFAULT_DATA_WIDTH = 16;
  parameter int DEFAULT_NUM_SPINS  = 8;

  // -------------------------------------------------------------------------
  // Annealing schedule types
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    SCHEDULE_LINEAR      = 2'b00,
    SCHEDULE_EXPONENTIAL = 2'b01,
    SCHEDULE_ADAPTIVE    = 2'b10
  } schedule_type_t;

  // -------------------------------------------------------------------------
  // Update strategy for spin array
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    UPDATE_SEQUENTIAL   = 2'b00,
    UPDATE_CHECKERBOARD = 2'b01,
    UPDATE_PARALLEL     = 2'b10
  } update_strategy_t;

  // -------------------------------------------------------------------------
  // RNG mode selection
  // -------------------------------------------------------------------------
  typedef enum logic {
    RNG_LFSR    = 1'b0,
    RNG_XORSHIFT = 1'b1
  } rng_mode_t;

  // -------------------------------------------------------------------------
  // Accelerator FSM states
  // -------------------------------------------------------------------------
  typedef enum logic [2:0] {
    STATE_IDLE      = 3'b000,
    STATE_CONFIGURE = 3'b001,
    STATE_ANNEALING = 3'b010,
    STATE_COOLDOWN  = 3'b011,
    STATE_FINISHED  = 3'b100
  } accel_state_t;

  // -------------------------------------------------------------------------
  // Configuration register addresses
  // -------------------------------------------------------------------------
  parameter logic [7:0] REG_CONTROL      = 8'h00;
  parameter logic [7:0] REG_STATUS       = 8'h04;
  parameter logic [7:0] REG_NUM_SPINS    = 8'h08;
  parameter logic [7:0] REG_INIT_TEMP    = 8'h0C;
  parameter logic [7:0] REG_COOL_RATE    = 8'h10;
  parameter logic [7:0] REG_SCHEDULE     = 8'h14;
  parameter logic [7:0] REG_STEPS_PER_T  = 8'h18;
  parameter logic [7:0] REG_BEST_ENERGY  = 8'h1C;
  parameter logic [7:0] REG_BEST_SPINS   = 8'h20;
  parameter logic [7:0] REG_WEIGHT_BASE  = 8'h40;
  parameter logic [7:0] REG_BIAS_BASE    = 8'h80;

  // -------------------------------------------------------------------------
  // Fixed-point multiplication for exponential cooling
  // Multiply a by b where b is in Q0.WIDTH format (fractional)
  // -------------------------------------------------------------------------
  function automatic logic [15:0] fp_multiply(
    input logic [15:0] a,
    input logic [15:0] b
  );
    logic [31:0] product;
    product = a * b;
    return product[31:16]; // Take upper 16 bits
  endfunction

endpackage
