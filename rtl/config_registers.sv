// =============================================================================
// Configuration Registers — Host Interface for Accelerator Control
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// AXI4-Lite inspired register bank for host-side configuration.
//
// Register Map:
//   0x00 — CONTROL:     [0] start, [1] clear
//   0x04 — STATUS:      [0] busy, [1] done, [2] converged
//   0x08 — NUM_SPINS:   active spin count (read-only, parameter)
//   0x0C — INIT_TEMP:   initial temperature
//   0x10 — COOL_RATE:   cooling rate
//   0x14 — SCHEDULE:    schedule type (0=linear, 1=exp, 2=adaptive)
//   0x18 — STEPS_PER_T: sweeps per temperature level
//   0x1C — BEST_ENERGY: best energy found (read-only)
//   0x20 — BEST_SPINS:  best spin config (read-only)
//   0x40 — WEIGHT_BASE: start of weight matrix (write-only, NUM_SPINS² words)
//   0x80 — BIAS_BASE:   start of bias vector (write-only, NUM_SPINS words)
// =============================================================================

module config_registers #(
    parameter int NUM_SPINS  = 8,
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = 12
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Simple bus interface
    input  logic                    wr_en,
    input  logic                    rd_en,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [31:0]             wr_data,
    output logic [31:0]             rd_data,
    output logic                    rd_valid,

    // Status inputs from accelerator
    input  logic                    accel_busy,
    input  logic                    accel_done,
    input  logic                    accel_converged,
    input  logic signed [2*DATA_WIDTH-1:0] best_energy_in,
    input  logic [NUM_SPINS-1:0]    best_spins_in,

    // Control outputs to accelerator
    output logic                    start,
    output logic                    clear,
    output logic [DATA_WIDTH-1:0]   init_temp,
    output logic [DATA_WIDTH-1:0]   cool_rate,
    output logic [1:0]              schedule_type,
    output logic [DATA_WIDTH-1:0]   steps_per_temp,
    output logic                    config_valid,

    // Weight and bias outputs
    output logic [DATA_WIDTH*NUM_SPINS*NUM_SPINS-1:0] weight_matrix_packed,
    output logic signed [DATA_WIDTH-1:0]              bias_vector [NUM_SPINS]
);

    // Internal registers
    logic [31:0] reg_control;
    logic [DATA_WIDTH-1:0] reg_init_temp;
    logic [DATA_WIDTH-1:0] reg_cool_rate;
    logic [1:0]  reg_schedule;
    logic [DATA_WIDTH-1:0] reg_steps;

    // Weight and bias storage
    logic signed [DATA_WIDTH-1:0] weight_mem [NUM_SPINS*NUM_SPINS];
    logic signed [DATA_WIDTH-1:0] bias_mem   [NUM_SPINS];

    // Control signal extraction
    assign start = reg_control[0];
    assign clear = reg_control[1];
    assign init_temp = reg_init_temp;
    assign cool_rate = reg_cool_rate;
    assign schedule_type = reg_schedule;
    assign steps_per_temp = reg_steps;

    // Pack weight memory into flat vector
    genvar wi;
    generate
        for (wi = 0; wi < NUM_SPINS * NUM_SPINS; wi++) begin : gen_weight_pack
            assign weight_matrix_packed[wi*DATA_WIDTH +: DATA_WIDTH] = weight_mem[wi];
        end
    endgenerate

    // Bias output
    always_comb begin
        for (int i = 0; i < NUM_SPINS; i++)
            bias_vector[i] = bias_mem[i];
    end

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_control   <= '0;
            reg_init_temp <= 16'h7FFF;
            reg_cool_rate <= 16'h0100;
            reg_schedule  <= 2'b00;
            reg_steps     <= 16'd256;
            config_valid  <= 1'b0;
            for (int i = 0; i < NUM_SPINS * NUM_SPINS; i++)
                weight_mem[i] <= '0;
            for (int i = 0; i < NUM_SPINS; i++)
                bias_mem[i] <= '0;
        end else begin
            config_valid <= 1'b0;

            // Auto-clear start after one cycle
            if (reg_control[0])
                reg_control[0] <= 1'b0;
            if (reg_control[1])
                reg_control[1] <= 1'b0;

            if (wr_en) begin
                case (addr[11:0])
                    12'h000: reg_control   <= wr_data;
                    12'h00C: begin
                        reg_init_temp <= wr_data[DATA_WIDTH-1:0];
                        config_valid  <= 1'b1;
                    end
                    12'h010: begin
                        reg_cool_rate <= wr_data[DATA_WIDTH-1:0];
                        config_valid  <= 1'b1;
                    end
                    12'h014: begin
                        reg_schedule  <= wr_data[1:0];
                        config_valid  <= 1'b1;
                    end
                    12'h018: reg_steps <= wr_data[DATA_WIDTH-1:0];
                    default: begin
                        // Weight matrix region: 0x040 - 0x07F
                        if (addr >= 12'h040 && addr < 12'h080) begin
                            automatic int idx = (int'(addr) - 'h040) >> 2;
                            if (idx < NUM_SPINS * NUM_SPINS)
                                weight_mem[idx] <= wr_data[DATA_WIDTH-1:0];
                        end
                        // Bias vector region: 0x080 - 0x0BF
                        if (addr >= 12'h080 && addr < 12'h0C0) begin
                            automatic int idx = (int'(addr) - 'h080) >> 2;
                            if (idx < NUM_SPINS)
                                bias_mem[idx] <= wr_data[DATA_WIDTH-1:0];
                        end
                    end
                endcase
            end
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data  <= '0;
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= 1'b0;
            if (rd_en) begin
                rd_valid <= 1'b1;
                case (addr[11:0])
                    12'h000: rd_data <= reg_control;
                    12'h004: rd_data <= {29'b0, accel_converged, accel_done, accel_busy};
                    12'h008: rd_data <= NUM_SPINS;
                    12'h00C: rd_data <= {{(32-DATA_WIDTH){1'b0}}, reg_init_temp};
                    12'h010: rd_data <= {{(32-DATA_WIDTH){1'b0}}, reg_cool_rate};
                    12'h014: rd_data <= {30'b0, reg_schedule};
                    12'h018: rd_data <= {{(32-DATA_WIDTH){1'b0}}, reg_steps};
                    12'h01C: rd_data <= best_energy_in[31:0];
                    12'h020: rd_data <= {{(32-NUM_SPINS){1'b0}}, best_spins_in};
                    default: rd_data <= 32'hDEAD_BEEF;
                endcase
            end
        end
    end

endmodule
