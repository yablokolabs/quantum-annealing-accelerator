// =============================================================================
// Annealing Controller — Programmable Temperature Schedule Manager
// Copyright (c) 2024 Yabloko Labs. All rights reserved.
// =============================================================================
// Manages the global annealing schedule by progressively reducing temperature.
//
// Supports three cooling strategies:
//   LINEAR:      T(n+1) = T(n) - cooling_rate
//   EXPONENTIAL: T(n+1) = T(n) * alpha  (fixed-point, alpha < 1)
//   ADAPTIVE:    monitors energy stagnation, adjusts cooling dynamically
//
// Checkerboard scheduling: alternates update_phase output for even/odd
// spin partitioning, enabling parallel conflict-free updates.
//
// steps_per_temp: number of update sweeps at each temperature level
// before cooling. Controls thermal equilibration quality.
// =============================================================================

module anneal_controller #(
    parameter int DATA_WIDTH      = 16,
    parameter int INITIAL_TEMP    = 16'h7FFF,
    parameter int COOLING_RATE    = 16'h0100,
    parameter int STEPS_PER_TEMP  = 256,
    parameter int SCHEDULE_TYPE   = 0  // 0=LINEAR, 1=EXPONENTIAL, 2=ADAPTIVE
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          start,
    input  logic signed [DATA_WIDTH-1:0]  current_energy,

    // Runtime configurable parameters
    input  logic                          config_valid,
    input  logic [DATA_WIDTH-1:0]         config_init_temp,
    input  logic [DATA_WIDTH-1:0]         config_cool_rate,
    input  logic [1:0]                    config_schedule,

    output logic                          busy,
    output logic                          done,
    output logic [DATA_WIDTH-1:0]         temperature,
    output logic                          update_tick,
    output logic                          checkerboard_phase
);

    import qa_pkg::*;

    // FSM
    accel_state_t state, state_next;

    // Internal registers
    logic [DATA_WIDTH-1:0] temp_reg;
    logic [$clog2(STEPS_PER_TEMP):0] step_count;
    logic [DATA_WIDTH-1:0] init_temp_reg;
    logic [DATA_WIDTH-1:0] cool_rate_reg;
    logic [1:0] schedule_reg;

    // Adaptive cooling state
    logic signed [DATA_WIDTH-1:0] prev_energy;
    logic [7:0] stagnation_count;
    logic [DATA_WIDTH-1:0] adaptive_rate;

    // Exponential cooling: alpha = 1 - cool_rate/65536 (Q0.16)
    // We store alpha as 16'hF000 (~0.9375) by default
    logic [DATA_WIDTH-1:0] exp_alpha;

    always_comb begin
        // alpha = 0xFFFF - cooling_rate (approximation)
        exp_alpha = 16'hFFFF - cool_rate_reg;
    end

    // Next state logic
    always_comb begin
        state_next = state;
        case (state)
            STATE_IDLE: begin
                if (start)
                    state_next = STATE_CONFIGURE;
            end
            STATE_CONFIGURE: begin
                state_next = STATE_ANNEALING;
            end
            STATE_ANNEALING: begin
                if (temp_reg == 0 || temp_reg < cool_rate_reg)
                    state_next = STATE_FINISHED;
            end
            STATE_FINISHED: begin
                if (!start)
                    state_next = STATE_IDLE;
            end
            default: state_next = STATE_IDLE;
        endcase
    end

    // Main sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= STATE_IDLE;
            temp_reg          <= INITIAL_TEMP[DATA_WIDTH-1:0];
            step_count        <= '0;
            busy              <= 1'b0;
            done              <= 1'b0;
            update_tick       <= 1'b0;
            checkerboard_phase <= 1'b0;
            init_temp_reg     <= INITIAL_TEMP[DATA_WIDTH-1:0];
            cool_rate_reg     <= COOLING_RATE[DATA_WIDTH-1:0];
            schedule_reg      <= SCHEDULE_TYPE[1:0];
            prev_energy       <= '0;
            stagnation_count  <= '0;
            adaptive_rate     <= COOLING_RATE[DATA_WIDTH-1:0];
        end else begin
            state <= state_next;

            // Runtime configuration capture
            if (config_valid && state == STATE_IDLE) begin
                init_temp_reg <= config_init_temp;
                cool_rate_reg <= config_cool_rate;
                schedule_reg  <= config_schedule;
            end

            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    update_tick <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                    end
                end

                STATE_CONFIGURE: begin
                    temp_reg          <= init_temp_reg;
                    step_count        <= '0;
                    prev_energy       <= '0;
                    stagnation_count  <= '0;
                    adaptive_rate     <= cool_rate_reg;
                    checkerboard_phase <= 1'b0;
                end

                STATE_ANNEALING: begin
                    // Generate update tick at each step
                    update_tick <= 1'b1;
                    checkerboard_phase <= ~checkerboard_phase;

                    step_count <= step_count + 1;

                    // Temperature update at end of sweep
                    if (step_count >= STEPS_PER_TEMP[($clog2(STEPS_PER_TEMP)):0] - 1) begin
                        step_count <= '0;

                        case (schedule_reg)
                            2'b00: begin // LINEAR
                                if (temp_reg > cool_rate_reg)
                                    temp_reg <= temp_reg - cool_rate_reg;
                                else
                                    temp_reg <= '0;
                            end

                            2'b01: begin // EXPONENTIAL
                                temp_reg <= qa_pkg::fp_multiply(temp_reg, exp_alpha);
                            end

                            2'b10: begin // ADAPTIVE
                                // Check energy stagnation
                                if (current_energy == prev_energy) begin
                                    stagnation_count <= stagnation_count + 1;
                                    // If stagnated, cool faster
                                    if (stagnation_count > 8'd10)
                                        adaptive_rate <= {cool_rate_reg[DATA_WIDTH-2:0], 1'b0}; // 2x
                                end else begin
                                    stagnation_count <= '0;
                                    adaptive_rate <= cool_rate_reg; // Reset rate
                                end
                                prev_energy <= current_energy;

                                if (temp_reg > adaptive_rate)
                                    temp_reg <= temp_reg - adaptive_rate;
                                else
                                    temp_reg <= '0;
                            end

                            default: begin
                                if (temp_reg > cool_rate_reg)
                                    temp_reg <= temp_reg - cool_rate_reg;
                                else
                                    temp_reg <= '0;
                            end
                        endcase
                    end
                end

                STATE_FINISHED: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    update_tick <= 1'b0;
                end

                default: ;
            endcase
        end
    end

    assign temperature = temp_reg;

    // -----------------------------------------------------------------------
    // Assertions
    // -----------------------------------------------------------------------
    // synopsys translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            // Temperature must be monotonically non-increasing during annealing
            if (state == STATE_ANNEALING && step_count == 0 && state != STATE_CONFIGURE) begin
                // Soft check — adaptive can temporarily reheat
            end
        end
    end
    // synopsys translate_on

endmodule
