// =============================================================================
// Spin Array — Scalable Array of P-Bit Spin Cells
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Instantiates NUM_SPINS spin cells, each with its own RNG and coupler.
//
// Update strategies:
//   PARALLEL     — all spins update simultaneously (fast, may have conflicts)
//   SEQUENTIAL   — one spin per clock cycle (safe, slow)
//   CHECKERBOARD — even spins, then odd spins (fast + conflict-free)
//
// The checkerboard strategy is the recommended default for Ising machines:
// spins only couple to opposite-parity neighbors, so updating all even
// spins simultaneously is conflict-free when using a bipartite graph.
// =============================================================================

module spin_array #(
    parameter int NUM_SPINS      = 8,
    parameter int DATA_WIDTH     = 16,
    parameter int UPDATE_STRATEGY = 2  // 0=SEQ, 1=CHECKERBOARD, 2=PARALLEL
)(
    input  logic                                      clk,
    input  logic                                      rst_n,
    input  logic                                      update_tick,
    input  logic                                      checkerboard_phase,
    input  logic [DATA_WIDTH-1:0]                     temperature,
    input  logic [DATA_WIDTH*NUM_SPINS*NUM_SPINS-1:0] weight_matrix_packed,
    input  logic signed [DATA_WIDTH-1:0]              bias_vector [NUM_SPINS],
    output logic [NUM_SPINS-1:0]                      spins,
    output logic signed [DATA_WIDTH-1:0]              energy_deltas [NUM_SPINS]
);

    // Internal signals
    logic [DATA_WIDTH-1:0] rand_vals    [NUM_SPINS];
    logic signed [DATA_WIDTH-1:0] local_fields [NUM_SPINS];
    logic [NUM_SPINS-1:0]         update_enables;

    // Sequential update counter
    logic [$clog2(NUM_SPINS)-1:0] seq_index;

    // Generate update enable signals based on strategy
    always_comb begin
        case (UPDATE_STRATEGY)
            0: begin // SEQUENTIAL
                update_enables = '0;
                if (update_tick)
                    update_enables[seq_index] = 1'b1;
            end
            1: begin // CHECKERBOARD
                for (int i = 0; i < NUM_SPINS; i++) begin
                    update_enables[i] = update_tick & (i[0] == checkerboard_phase);
                end
            end
            default: begin // PARALLEL
                update_enables = update_tick ? {NUM_SPINS{1'b1}} : '0;
            end
        endcase
    end

    // Sequential index counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            seq_index <= '0;
        else if (update_tick && UPDATE_STRATEGY == 0) begin
            if (seq_index == ($clog2(NUM_SPINS))'(NUM_SPINS - 1))
                seq_index <= '0;
            else
                seq_index <= seq_index + 1;
        end
    end

    // Instantiate spin infrastructure
    genvar i;
    generate
        for (i = 0; i < NUM_SPINS; i++) begin : gen_spin

            // Per-spin RNG with unique seed
            rng_module #(
                .WIDTH(DATA_WIDTH),
                .SEED(16'hACE1 + i[15:0] * 16'h1337)
            ) u_rng (
                .clk(clk),
                .rst_n(rst_n),
                .en(update_enables[i]),
                .seed_load(1'b0),
                .seed_val('0),
                .rand_out(rand_vals[i])
            );

            // Per-spin coupler
            ising_coupler #(
                .NUM_SPINS(NUM_SPINS),
                .DATA_WIDTH(DATA_WIDTH),
                .PIPELINED(NUM_SPINS > 16 ? 1 : 0)
            ) u_coupler (
                .clk(clk),
                .rst_n(rst_n),
                .spins(spins),
                .weights_packed(weight_matrix_packed[i*NUM_SPINS*DATA_WIDTH +: NUM_SPINS*DATA_WIDTH]),
                .bias(bias_vector[i]),
                .local_field(local_fields[i]),
                .field_valid(/* unused in parallel mode */)
            );

            // Spin cell
            spin_cell #(
                .DATA_WIDTH(DATA_WIDTH)
            ) u_spin (
                .clk(clk),
                .rst_n(rst_n),
                .update_en(update_enables[i]),
                .local_field(local_fields[i]),
                .rand_val(rand_vals[i]),
                .temperature(temperature),
                .spin_state(spins[i]),
                .energy_delta(energy_deltas[i])
            );

        end
    endgenerate

endmodule
