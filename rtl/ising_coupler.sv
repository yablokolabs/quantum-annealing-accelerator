// =============================================================================
// Ising Coupler — Local Field Computation Engine
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Computes the effective local field for spin i:
//
//   h_eff_i = Σ_j (J_ij · σ_j) + h_i
//
// where J_ij is the coupling weight between spins i and j,
// σ_j is the spin state of neighbor j (+1 or -1),
// and h_i is the external bias field.
//
// Spin encoding: logic 1 → σ = +1, logic 0 → σ = -1
//
// The weight matrix is packed into a flat vector for SRAM-friendly access.
// Optional pipeline register for timing closure at large spin counts.
// =============================================================================

module ising_coupler #(
    parameter int NUM_SPINS  = 8,
    parameter int DATA_WIDTH = 16,
    parameter bit PIPELINED  = 0  // Set 1 for timing closure at large spin counts
)(
    input  logic                                      clk,       // Used in pipelined mode
    input  logic                                      rst_n,     // Used in pipelined mode
    input  logic [NUM_SPINS-1:0]                      spins,
    input  logic signed [DATA_WIDTH*NUM_SPINS-1:0]    weights_packed,
    input  logic signed [DATA_WIDTH-1:0]              bias,
    output logic signed [DATA_WIDTH-1:0]              local_field,
    output logic                                      field_valid
);

    logic signed [DATA_WIDTH-1:0] w;
    /* verilator lint_off UNUSEDSIGNAL */
    logic signed [DATA_WIDTH+$clog2(NUM_SPINS):0] accumulator;
    /* verilator lint_on UNUSEDSIGNAL */

    // Combinational accumulation
    always_comb begin
        accumulator = {{($clog2(NUM_SPINS)+1){bias[DATA_WIDTH-1]}}, bias};
        for (int j = 0; j < NUM_SPINS; j++) begin
            w = weights_packed[j*DATA_WIDTH +: DATA_WIDTH];
            if (spins[j])
                accumulator = accumulator + {{($clog2(NUM_SPINS)+1){w[DATA_WIDTH-1]}}, w};
            else
                accumulator = accumulator - {{($clog2(NUM_SPINS)+1){w[DATA_WIDTH-1]}}, w};
        end
    end

    generate
        if (PIPELINED) begin : gen_pipelined
            // Pipeline register for timing closure
            logic signed [DATA_WIDTH-1:0] field_reg;
            logic valid_reg;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    field_reg <= '0;
                    valid_reg <= 1'b0;
                end else begin
                    // Saturate to DATA_WIDTH
                    field_reg <= accumulator[DATA_WIDTH-1:0];
                    valid_reg <= 1'b1;
                end
            end

            assign local_field = field_reg;
            assign field_valid = valid_reg;

        end else begin : gen_combinational
            // Direct combinational output
            assign local_field = accumulator[DATA_WIDTH-1:0];
            assign field_valid = 1'b1;
        end
    endgenerate

endmodule
