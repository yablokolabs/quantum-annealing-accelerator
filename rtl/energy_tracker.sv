// =============================================================================
// Energy Tracker — System Hamiltonian Computation & Best-Solution Tracker
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Computes the Ising Hamiltonian energy:
//   E = -Σ_{i<j} J_ij σ_i σ_j - Σ_i h_i σ_i
//
// Maintains a running best energy and corresponding spin configuration.
// Detects convergence when energy remains stable for CONVERGE_THRESHOLD cycles.
// =============================================================================

module energy_tracker #(
    parameter int NUM_SPINS          = 8,
    parameter int DATA_WIDTH         = 16,
    parameter int CONVERGE_THRESHOLD = 64
)(
    input  logic                                      clk,
    input  logic                                      rst_n,
    input  logic                                      enable,
    input  logic                                      clear,
    input  logic [NUM_SPINS-1:0]                      spins,
    input  logic [DATA_WIDTH*NUM_SPINS*NUM_SPINS-1:0] weight_matrix_packed,
    input  logic signed [DATA_WIDTH-1:0]              bias_vector [NUM_SPINS],
    output logic signed [2*DATA_WIDTH-1:0]            current_energy,
    output logic signed [2*DATA_WIDTH-1:0]            best_energy,
    output logic [NUM_SPINS-1:0]                      best_spins,
    output logic                                      converged
);

    // Internal signals
    logic signed [2*DATA_WIDTH-1:0] computed_energy;
    logic signed [DATA_WIDTH-1:0]   w_ij;
    logic [$clog2(CONVERGE_THRESHOLD):0] stable_count;

    // Compute full Hamiltonian (combinational)
    always_comb begin
        computed_energy = '0;

        // Coupling term: -Σ_{i<j} J_ij σ_i σ_j
        for (int i = 0; i < NUM_SPINS; i++) begin
            for (int j = i + 1; j < NUM_SPINS; j++) begin
                w_ij = weight_matrix_packed[(i*NUM_SPINS + j)*DATA_WIDTH +: DATA_WIDTH];
                // σ_i σ_j: same sign → +1, different → -1
                if (spins[i] == spins[j])
                    computed_energy = computed_energy - {{DATA_WIDTH{w_ij[DATA_WIDTH-1]}}, w_ij};
                else
                    computed_energy = computed_energy + {{DATA_WIDTH{w_ij[DATA_WIDTH-1]}}, w_ij};
            end
        end

        // Bias term: -Σ_i h_i σ_i
        for (int i = 0; i < NUM_SPINS; i++) begin
            if (spins[i])
                computed_energy = computed_energy -
                    {{DATA_WIDTH{bias_vector[i][DATA_WIDTH-1]}}, bias_vector[i]};
            else
                computed_energy = computed_energy +
                    {{DATA_WIDTH{bias_vector[i][DATA_WIDTH-1]}}, bias_vector[i]};
        end
    end

    // Sequential: track best and convergence
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_energy <= '0;
            best_energy    <= {1'b0, {(2*DATA_WIDTH-1){1'b1}}}; // Max positive
            best_spins     <= '0;
            stable_count   <= '0;
            converged      <= 1'b0;
        end else if (clear) begin
            current_energy <= '0;
            best_energy    <= {1'b0, {(2*DATA_WIDTH-1){1'b1}}};
            best_spins     <= '0;
            stable_count   <= '0;
            converged      <= 1'b0;
        end else if (enable) begin
            current_energy <= computed_energy;

            // Update best if lower energy found
            if ($signed(computed_energy) < $signed(best_energy)) begin
                best_energy  <= computed_energy;
                best_spins   <= spins;
                stable_count <= '0;
                converged    <= 1'b0;
            end else begin
                // Convergence detection
                if (computed_energy == current_energy) begin
                    if (stable_count < CONVERGE_THRESHOLD[($clog2(CONVERGE_THRESHOLD)):0])
                        stable_count <= stable_count + 1;
                    else
                        converged <= 1'b1;
                end else begin
                    stable_count <= '0;
                end
            end
        end
    end

endmodule
