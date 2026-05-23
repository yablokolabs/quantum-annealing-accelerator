`timescale 1ns/1ps
// =============================================================================
// Testbench: Ising Coupler
// =============================================================================

module tb_ising_coupler();

    parameter NUM_SPINS  = 4;
    parameter DATA_WIDTH = 16;

    logic                                  clk;
    logic                                  rst_n;
    logic [NUM_SPINS-1:0]                  spins;
    logic signed [DATA_WIDTH*NUM_SPINS-1:0] weights_packed;
    logic signed [DATA_WIDTH-1:0]          bias;
    logic signed [DATA_WIDTH-1:0]          local_field;
    logic                                  field_valid;

    ising_coupler #(
        .NUM_SPINS(NUM_SPINS),
        .DATA_WIDTH(DATA_WIDTH),
        .PIPELINED(0)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("ising_coupler.vcd");
        $dumpvars(0, tb_ising_coupler);

        rst_n = 1;

        // Test 1: All weights zero → local_field = bias
        spins = 4'b1010;
        weights_packed = '0;
        bias = 16'sh0042;
        #10;
        assert(local_field == 16'sh0042)
            else $error("FAIL: Zero weights, expected field=%0d, got %0d", 16'sh0042, local_field);
        $display("PASS: Zero weights → field = bias (%0d)", local_field);

        // Test 2: Known weight pattern
        // spins = 1111 (all +1), weights = [1, 2, 3, 4], bias = 0
        // field = 1 + 2 + 3 + 4 = 10
        spins = 4'b1111;
        weights_packed[0*DATA_WIDTH +: DATA_WIDTH] = 16'sh0001;
        weights_packed[1*DATA_WIDTH +: DATA_WIDTH] = 16'sh0002;
        weights_packed[2*DATA_WIDTH +: DATA_WIDTH] = 16'sh0003;
        weights_packed[3*DATA_WIDTH +: DATA_WIDTH] = 16'sh0004;
        bias = 16'sh0000;
        #10;
        assert(local_field == 16'sh000A)
            else $error("FAIL: Expected field=10, got %0d", local_field);
        $display("PASS: All spins up, weights [1,2,3,4] → field = %0d", local_field);

        // Test 3: Mixed spins
        // spins = 1010 → σ = [+1, -1, +1, -1]
        // field = 1*1 + 2*(-1) + 3*1 + 4*(-1) = 1-2+3-4 = -2
        spins = 4'b1010;
        bias = 16'sh0000;
        #10;
        assert(local_field == -16'sh0002)
            else $error("FAIL: Expected field=-2, got %0d", local_field);
        $display("PASS: Mixed spins [+,-,+,-], weights [1,2,3,4] → field = %0d", local_field);

        // Test 4: All spins down
        // spins = 0000 → σ = [-1,-1,-1,-1]
        // field = -(1+2+3+4) = -10
        spins = 4'b0000;
        #10;
        assert(local_field == -16'sh000A)
            else $error("FAIL: Expected field=-10, got %0d", local_field);
        $display("PASS: All spins down → field = %0d", local_field);

        // Test 5: Negative weights
        weights_packed[0*DATA_WIDTH +: DATA_WIDTH] = -16'sh0005;
        weights_packed[1*DATA_WIDTH +: DATA_WIDTH] = -16'sh0005;
        weights_packed[2*DATA_WIDTH +: DATA_WIDTH] = -16'sh0005;
        weights_packed[3*DATA_WIDTH +: DATA_WIDTH] = -16'sh0005;
        spins = 4'b1111;
        bias = 16'sh0000;
        #10;
        assert(local_field == -16'sh0014)
            else $error("FAIL: Negative weights, expected -20, got %0d", local_field);
        $display("PASS: Negative weights → field = %0d", local_field);

        $display("=== ISING COUPLER: ALL TESTS PASSED ===");
        #20 $finish;
    end

endmodule
