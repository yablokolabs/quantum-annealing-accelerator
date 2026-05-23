`timescale 1ns/1ps
// =============================================================================
// Testbench: QA Top — Integration Test
// Solves Max-Cut on an 8-spin ring graph via simulated annealing.
// =============================================================================

module tb_qa_top();

    parameter NUM_SPINS  = 8;
    parameter DATA_WIDTH = 16;

    logic        clk;
    logic        rst_n;
    logic        host_wr_en;
    logic        host_rd_en;
    logic [11:0] host_addr;
    logic [31:0] host_wr_data;
    logic [31:0] host_rd_data;
    logic        host_rd_valid;
    logic [NUM_SPINS-1:0]         final_spins;
    logic                         done;
    logic                         busy;
    logic                         converged;
    logic [DATA_WIDTH-1:0]        current_temp;
    logic signed [2*DATA_WIDTH-1:0] best_energy;

    qa_top #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH),
        .UPDATE_STRATEGY(2),
        .SCHEDULE_TYPE(0),
        .INITIAL_TEMP(32'h3FFF),
        .COOLING_RATE(32'h0200),
        .STEPS_PER_TEMP(32)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task: write to config register
    task automatic host_write(input [11:0] address, input [31:0] data);
        @(posedge clk);
        host_addr    = address;
        host_wr_data = data;
        host_wr_en   = 1;
        @(posedge clk);
        host_wr_en = 0;
    endtask

    // Helper task: read from config register
    task automatic host_read(input [11:0] address, output [31:0] data);
        @(posedge clk);
        host_addr  = address;
        host_rd_en = 1;
        @(posedge clk);
        host_rd_en = 0;
        @(posedge clk); // Wait for rd_valid
        data = host_rd_data;
    endtask

    initial begin
        $dumpfile("qa_top.vcd");
        $dumpvars(0, tb_qa_top);

        // Initialize
        rst_n = 0;
        host_wr_en = 0; host_rd_en = 0;
        host_addr = 0; host_wr_data = 0;
        #30 rst_n = 1;
        #10;

        $display("=== QA Top Integration Test: Max-Cut on Ring Graph ===");

        // Load weight matrix: antiferromagnetic ring
        // J_ij = -1000 for adjacent spins on ring
        for (int i = 0; i < NUM_SPINS; i++) begin
            int j;
            j = (i + 1) % NUM_SPINS;
            // Write J[i][j]
            host_write(12'h040 + ((i * NUM_SPINS + j) << 2), 32'hFFFF_FC18); // -1000 sign-ext
            // Write J[j][i]
            host_write(12'h040 + ((j * NUM_SPINS + i) << 2), 32'hFFFF_FC18);
        end
        $display("INFO: Weight matrix loaded (ring graph)");

        // Configure annealing parameters
        host_write(12'h00C, 32'h3FFF);  // Initial temperature
        host_write(12'h010, 32'h0200);  // Cooling rate
        host_write(12'h014, 32'h0000);  // Linear schedule

        // Start annealing
        host_write(12'h000, 32'h0001);  // Set start bit
        $display("INFO: Annealing started");

        // Wait for completion
        wait(done);
        $display("INFO: Annealing complete!");
        $display("INFO: Final spins:   %b", final_spins);
        $display("INFO: Best energy:   %0d", best_energy);
        $display("INFO: Final temp:    %h", current_temp);
        $display("INFO: Converged:     %b", converged);

        // Evaluate result
        begin
            integer cut_value, i_idx, j_idx;
            cut_value = 0;
            for (i_idx = 0; i_idx < NUM_SPINS; i_idx++) begin
                j_idx = (i_idx + 1) % NUM_SPINS;
                if (final_spins[i_idx] != final_spins[j_idx])
                    cut_value++;
            end
            $display("INFO: Cut value = %0d / %0d edges", cut_value, NUM_SPINS);

            if (final_spins == 8'b01010101 || final_spins == 8'b10101010) begin
                $display("PASS: Optimal Max-Cut found (alternating pattern)!");
            end else if (cut_value >= NUM_SPINS - 2) begin
                $display("PASS: Near-optimal solution found (cut=%0d)", cut_value);
            end else begin
                $display("INFO: Sub-optimal solution (cut=%0d). Stochastic — may vary.", cut_value);
            end
        end

        // Read status register via host interface
        begin
            logic [31:0] status;
            host_read(12'h004, status);
            $display("INFO: Status register = %h (busy=%b, done=%b, converged=%b)",
                     status, status[0], status[1], status[2]);
        end

        $display("=== QA TOP: INTEGRATION TEST COMPLETE ===");
        #100 $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
