`timescale 1ns/1ps
// =============================================================================
// Testbench: RNG Module
// =============================================================================

module tb_rng_module();

    parameter WIDTH = 16;
    parameter SEED  = 16'hACE1;

    logic             clk;
    logic             rst_n;
    logic             en;
    logic             seed_load;
    logic [WIDTH-1:0] seed_val;
    logic [WIDTH-1:0] rand_out;

    rng_module #(
        .WIDTH(WIDTH),
        .SEED(SEED),
        .XORSHIFT_MODE(0)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer i;
    logic [WIDTH-1:0] prev_val;
    integer unique_count;

    initial begin
        $dumpfile("rng_module.vcd");
        $dumpvars(0, tb_rng_module);

        rst_n = 0; en = 0; seed_load = 0; seed_val = 0;
        #20 rst_n = 1;

        // Verify initial state equals seed
        #10;
        assert(rand_out == SEED) else $error("FAIL: Initial state != SEED, got %h", rand_out);
        $display("PASS: Initial state = SEED (%h)", rand_out);

        // Run for 100 cycles, verify non-zero
        en = 1;
        unique_count = 0;
        prev_val = rand_out;
        for (i = 0; i < 100; i++) begin
            @(posedge clk);
            #1;
            assert(rand_out != 0) else $error("FAIL: RNG output zero at cycle %0d", i);
            if (rand_out != prev_val) unique_count++;
            prev_val = rand_out;
        end
        $display("PASS: %0d unique transitions in 100 cycles", unique_count);
        assert(unique_count > 50) else $error("FAIL: Too few unique values");

        // Verify enable gating
        en = 0;
        prev_val = rand_out;
        repeat(10) @(posedge clk);
        #1;
        assert(rand_out == prev_val) else $error("FAIL: RNG changed while disabled");
        $display("PASS: Enable gating works");

        // Verify seed reload
        seed_val = 16'hBEEF;
        seed_load = 1;
        @(posedge clk);
        #1;
        seed_load = 0;
        assert(rand_out == 16'hBEEF) else $error("FAIL: Seed reload failed");
        $display("PASS: Seed reload works");

        // Verify deterministic replay
        rst_n = 0;
        #20;
        rst_n = 1;
        en = 1;
        #10;
        // Should be back at SEED
        assert(rand_out == SEED) else $error("FAIL: Reset replay failed");
        $display("PASS: Deterministic replay after reset");

        $display("=== RNG MODULE: ALL TESTS PASSED ===");
        #20 $finish;
    end

endmodule
