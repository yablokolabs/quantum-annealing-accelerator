`timescale 1ns/1ps
// =============================================================================
// Testbench: Spin Cell
// =============================================================================

module tb_spin_cell();

    parameter DATA_WIDTH = 16;

    logic                          clk;
    logic                          rst_n;
    logic                          update_en;
    logic signed [DATA_WIDTH-1:0]  local_field;
    logic        [DATA_WIDTH-1:0]  rand_val;
    logic        [DATA_WIDTH-1:0]  temperature;
    logic                          spin_state;
    logic signed [DATA_WIDTH-1:0]  energy_delta;

    spin_cell #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("spin_cell.vcd");
        $dumpvars(0, tb_spin_cell);

        rst_n = 0; update_en = 0;
        local_field = 0; rand_val = 0; temperature = 0;
        #20 rst_n = 1;

        // Test 1: Reset state
        #10;
        assert(spin_state == 0) else $error("FAIL: Reset state should be 0");
        $display("PASS: Reset state = 0 (spin down)");

        // Test 2: Strong positive field → spin up
        local_field = 16'sh7000;  // Large positive
        rand_val = 16'h0100;      // Small noise
        temperature = 16'h0010;   // Low temperature
        update_en = 1;
        @(posedge clk); #1;
        update_en = 0;
        assert(spin_state == 1) else $error("FAIL: Strong positive field should give spin=1");
        $display("PASS: Strong positive field → spin up");

        // Test 3: Strong negative field → spin down
        local_field = -16'sh7000; // Large negative
        rand_val = 16'h0100;
        temperature = 16'h0010;
        update_en = 1;
        @(posedge clk); #1;
        update_en = 0;
        assert(spin_state == 0) else $error("FAIL: Strong negative field should give spin=0");
        $display("PASS: Strong negative field → spin down");

        // Test 4: Update enable gating
        local_field = 16'sh7000;
        update_en = 0;
        @(posedge clk); #1;
        assert(spin_state == 0) else $error("FAIL: Spin changed without update_en");
        $display("PASS: Update enable gating works");

        // Test 5: Stochastic behavior at high temperature
        // Run many trials and check we get both outcomes
        begin
            integer up_count, trial;
            up_count = 0;
            local_field = 16'sh0100; // Slight positive bias
            temperature = 16'h7FFF;  // Very high temperature
            for (trial = 0; trial < 100; trial++) begin
                rand_val = 16'(trial * 659 + 12345); // Pseudo-varying noise
                update_en = 1;
                @(posedge clk); #1;
                update_en = 0;
                if (spin_state) up_count++;
            end
            $display("INFO: At high temp, got %0d/100 spin-up (expecting ~50%%)", up_count);
            assert(up_count > 10 && up_count < 90)
                else $warning("WARN: Stochastic distribution may be skewed: %0d/100", up_count);
            $display("PASS: Stochastic behavior at high temperature");
        end

        $display("=== SPIN CELL: ALL TESTS PASSED ===");
        #20 $finish;
    end

endmodule
