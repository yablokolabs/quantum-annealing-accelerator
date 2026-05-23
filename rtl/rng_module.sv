// =============================================================================
// RNG Module — Parameterized Pseudo-Random Number Generator
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Provides pseudo-random values for stochastic spin updates.
// Supports two modes:
//   LFSR     — Galois linear feedback shift register (default)
//   XORSHIFT — xorshift32 algorithm for improved distribution
//
// Deterministic: identical seed produces identical sequence.
// =============================================================================

module rng_module #(
    parameter int WIDTH = 16,
    parameter logic [WIDTH-1:0] SEED = 16'hACE1,
    parameter bit XORSHIFT_MODE = 0
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  logic             seed_load,
    input  logic [WIDTH-1:0] seed_val,
    output logic [WIDTH-1:0] rand_out
);

    logic [WIDTH-1:0] state;

    generate
        if (XORSHIFT_MODE) begin : gen_xorshift
            // xorshift algorithm adapted for parameterized width
            logic [WIDTH-1:0] x1, x2, x3;

            always_comb begin
                x1 = state ^ (state << 7);
                x2 = x1 ^ (x1 >> 9);
                x3 = x2 ^ (x2 << 8);
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    state <= SEED;
                else if (seed_load)
                    state <= (seed_val == '0) ? SEED : seed_val;
                else if (en)
                    state <= x3;
            end

        end else begin : gen_lfsr
            // Galois LFSR with maximal-length polynomial
            // 16-bit: x^16 + x^14 + x^13 + x^11 + 1
            logic feedback;

            always_comb begin
                feedback = state[WIDTH-1] ^ state[WIDTH-3] ^
                           state[WIDTH-4] ^ state[WIDTH-6];
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    state <= SEED;
                else if (seed_load)
                    state <= (seed_val == '0) ? SEED : seed_val;
                else if (en)
                    state <= {state[WIDTH-2:0], feedback};
            end
        end
    endgenerate

    assign rand_out = state;

    // -----------------------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------------------
    // synopsys translate_off
    always @(posedge clk) begin
        if (rst_n && en) begin
            assert (state != '0)
                else $error("RNG: LFSR entered all-zero state — loss of randomness");
        end
    end
    // synopsys translate_on

endmodule
