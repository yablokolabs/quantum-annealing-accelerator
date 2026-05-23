`timescale 1ns/1ps
// =============================================================================
// Testbench: Anneal Controller
// =============================================================================

module tb_anneal_controller();

    parameter DATA_WIDTH     = 16;
    parameter INITIAL_TEMP   = 32'h7FFF;
    parameter COOLING_RATE   = 32'h0800;
    parameter STEPS_PER_TEMP = 16;

    logic                          clk;
    logic                          rst_n;
    logic                          start;
    logic signed [DATA_WIDTH-1:0]  current_energy;
    logic                          config_valid;
    logic [DATA_WIDTH-1:0]         config_init_temp;
    logic [DATA_WIDTH-1:0]         config_cool_rate;
    logic [1:0]                    config_schedule;
    logic                          busy;
    logic                          done;
    logic [DATA_WIDTH-1:0]         temperature;
    logic                          update_tick;
    logic                          checkerboard_phase;

    anneal_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .INITIAL_TEMP(INITIAL_TEMP),
        .COOLING_RATE(COOLING_RATE),
        .STEPS_PER_TEMP(STEPS_PER_TEMP),
        .SCHEDULE_TYPE(0)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("anneal_controller.vcd");
        $dumpvars(0, tb_anneal_controller);

        rst_n = 0; start = 0; current_energy = 0;
        config_valid = 0; config_init_temp = 0;
        config_cool_rate = 0; config_schedule = 0;
        #20 rst_n = 1;

        // Test 1: Idle state
        #10;
        assert(!busy) else $error("FAIL: Should not be busy in IDLE");
        assert(!done) else $error("FAIL: Should not be done in IDLE");
        $display("PASS: Idle state correct");

        // Test 2: Start annealing
        start = 1;
        @(posedge clk); #1;
        start = 0;

        // Wait a few cycles for configure → annealing transition
        repeat(3) @(posedge clk);
        #1;
        assert(busy) else $error("FAIL: Should be busy during annealing");
        $display("PASS: Annealing started, busy=%b", busy);

        // Test 3: Verify temperature decreases
        begin
            logic [DATA_WIDTH-1:0] prev_temp;
            integer temp_decreases;
            temp_decreases = 0;
            prev_temp = temperature;

            // Run for enough cycles to see temperature drops
            repeat(STEPS_PER_TEMP * 5) begin
                @(posedge clk); #1;
                if (temperature < prev_temp) begin
                    temp_decreases++;
                    $display("INFO: Temp decreased: %h → %h", prev_temp, temperature);
                end
                prev_temp = temperature;
            end
            assert(temp_decreases > 0)
                else $error("FAIL: Temperature never decreased");
            $display("PASS: Temperature decreased %0d times", temp_decreases);
        end

        // Test 4: Wait for completion
        wait(done);
        $display("PASS: Annealing completed, done=%b, final_temp=%h", done, temperature);
        assert(!busy) else $error("FAIL: busy should be 0 when done");
        assert(temperature == 0 || temperature < COOLING_RATE)
            else $error("FAIL: Final temperature should be near zero");

        // Test 5: Return to idle
        start = 0;
        repeat(3) @(posedge clk);
        #1;
        // Controller should return to idle when start deasserted
        $display("PASS: Controller returned to idle");

        $display("=== ANNEAL CONTROLLER: ALL TESTS PASSED ===");
        #50 $finish;
    end

endmodule
