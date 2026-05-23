// =============================================================================
// Spin Cell — Probabilistic Spin Update Engine (P-Bit)
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Implements a single probabilistic bit (p-bit) for the Ising machine.
//
// Update rule (hardware-friendly linearized sigmoid):
//   P(σ_i = +1) ≈ sigmoid(β · h_eff_i)
//
// Hardware approximation:
//   If (h_eff_i + scaled_noise) > 0 → spin = +1
//   Else → spin = -1
//
// Temperature controls noise magnitude:
//   High T → large noise → random behavior (exploration)
//   Low  T → small noise → deterministic (exploitation)
//
// Energy delta output enables running energy computation:
//   ΔE = -2 · σ_i · h_eff_i  (only valid on update cycle)
// =============================================================================

module spin_cell #(
    parameter int DATA_WIDTH = 16
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          update_en,
    input  logic signed [DATA_WIDTH-1:0]  local_field,
    input  logic        [DATA_WIDTH-1:0]  rand_val,
    input  logic        [DATA_WIDTH-1:0]  temperature,
    output logic                          spin_state,
    output logic signed [DATA_WIDTH-1:0]  energy_delta
);

    // Stochastic threshold computation
    // noise = rand_val scaled by temperature
    // threshold = local_field + noise - temperature_offset
    logic signed [DATA_WIDTH:0] threshold;
    logic signed [DATA_WIDTH:0] noise_term;
    logic signed [DATA_WIDTH:0] field_ext;

    always_comb begin
        // Sign-extend local field
        field_ext = {local_field[DATA_WIDTH-1], local_field};

        // Scale random value: treat as unsigned noise centered around T/2
        // noise_term = rand_val[WIDTH-2:0] - temperature/2
        noise_term = $signed({1'b0, rand_val[DATA_WIDTH-2:0]}) -
                     $signed({2'b00, temperature[DATA_WIDTH-1:1]});

        // Decision: spin up if field + noise > 0
        threshold = field_ext + noise_term;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spin_state <= 1'b0;
        end else if (update_en) begin
            spin_state <= (threshold > 0) ? 1'b1 : 1'b0;
        end
    end

    // Energy delta for running Hamiltonian tracking
    // ΔE = -2 * σ_i * h_eff_i (in spin {-1,+1} domain)
    // When spin_state=1 (σ=+1): ΔE = -2 * h_eff
    // When spin_state=0 (σ=-1): ΔE = +2 * h_eff
    always_comb begin
        if (spin_state)
            energy_delta = -{1'b0, local_field[DATA_WIDTH-1:1]}; // -h_eff (approx -2*h/2)
        else
            energy_delta = {1'b0, local_field[DATA_WIDTH-1:1]};  // +h_eff
    end

    // -----------------------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------------------
    // synopsys translate_off
    initial begin
        assert (DATA_WIDTH >= 8)
            else $fatal(1, "spin_cell: DATA_WIDTH must be >= 8 for meaningful precision");
    end
    // synopsys translate_on

endmodule
