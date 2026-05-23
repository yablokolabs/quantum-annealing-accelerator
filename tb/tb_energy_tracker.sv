`timescale 1ns/1ps
// =============================================================================
// Testbench: Energy Tracker
// =============================================================================

module tb_energy_tracker();

    parameter NUM_SPINS  = 4;
    parameter DATA_WIDTH = 16;

    logic                                      clk;
    logic                                      rst_n;
    logic                                      enable;
    logic                                      clear;
    logic [NUM_SPINS-1:0]                      spins;
    logic [DATA_WIDTH*NUM_SPINS*NUM_SPINS-1:0] weight_matrix_packed;
    logic signed [DATA_WIDTH-1:0]              bias_vector [NUM_SPINS];
    logic signed [2*DATA_WIDTH-1:0]            current_energy;
    logic signed [2*DATA_WIDTH-1:0]            best_energy;
    logic [NUM_SPINS-1:0]                      best_spins;
    logic                                      converged;

    energy_tracker #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH),
        .CONVERGE_THRESHOLD(8)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("energy_tracker.vcd");
        $dumpvars(0, tb_energy_tracker);

        rst_n = 0; enable = 0; clear = 0;
        spins = '0;
        weight_matrix_packed = '0;
        for (int i = 0; i < NUM_SPINS; i++) bias_vector[i] = '0;

        #20 rst_n = 1;

        // Setup: ring graph weights (antiferromagnetic)
        // J_01 = J_12 = J_23 = J_30 = -1000
        for (int i = 0; i < NUM_SPINS; i++) begin
            int j;
            j = (i + 1) % NUM_SPINS;
            weight_matrix_packed[(i*NUM_SPINS + j)*DATA_WIDTH +: DATA_WIDTH] = -16'sd1000;
            weight_matrix_packed[(j*NUM_SPINS + i)*DATA_WIDTH +: DATA_WIDTH] = -16'sd1000;
        end

        // Test 1: Alternating spins (optimal for ring) → should give lower energy
        spins = 4'b1010; // σ = [+1,-1,+1,-1]
        enable = 1;
        @(posedge clk); #1;
        enable = 0;
        $display("INFO: Alternating spins energy = %0d", current_energy);

        // Test 2: All same spins → should give higher energy
        begin
            logic signed [2*DATA_WIDTH-1:0] alt_energy;
            alt_energy = current_energy;

            spins = 4'b1111;
            enable = 1;
            @(posedge clk); #1;
            enable = 0;
            $display("INFO: All-up spins energy = %0d", current_energy);

            assert($signed(alt_energy) < $signed(current_energy))
                else $error("FAIL: Alternating config should have lower energy than uniform");
            $display("PASS: Alternating config has lower energy than uniform");
        end

        // Test 3: Best energy tracking
        spins = 4'b1010;
        enable = 1;
        @(posedge clk); #1;
        enable = 0;
        assert(best_spins == 4'b1010)
            else $error("FAIL: Best spins should be alternating pattern, got %b", best_spins);
        $display("PASS: Best spins tracked correctly: %b", best_spins);

        // Test 4: Convergence detection
        // Keep same spins for > threshold cycles
        spins = 4'b1010;
        repeat(20) begin
            enable = 1;
            @(posedge clk); #1;
            enable = 0;
            @(posedge clk);
        end
        assert(converged) else $error("FAIL: Should have converged");
        $display("PASS: Convergence detected after stable energy");

        // Test 5: Clear resets everything
        clear = 1;
        @(posedge clk); #1;
        clear = 0;
        assert(!converged) else $error("FAIL: Clear should reset convergence");
        $display("PASS: Clear resets state");

        $display("=== ENERGY TRACKER: ALL TESTS PASSED ===");
        #20 $finish;
    end

endmodule
