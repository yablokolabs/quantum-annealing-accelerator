export interface Port {
  name: string;
  direction: "input" | "output";
  width: number;
}

export interface ModuleParam {
  name: string;
  defaultValue: string;
  description: string;
}

export interface RTLModule {
  name: string;
  description: string;
  ports: Port[];
  parameters: ModuleParam[];
  code: string;
  signalFlow: string;
}

export const rtlModules: RTLModule[] = [
  {
    name: "qa_top",
    description:
      "Top-level module for the Quantum Annealing Accelerator. Integrates the spin array, annealing controller, configuration registers, and energy tracker into a unified pipeline.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "cfg_data", direction: "input", width: 32 },
      { name: "cfg_addr", direction: "input", width: 8 },
      { name: "cfg_wr", direction: "input", width: 1 },
      { name: "start", direction: "input", width: 1 },
      { name: "done", direction: "output", width: 1 },
      { name: "best_energy", direction: "output", width: 32 },
      { name: "best_spins", direction: "output", width: 64 },
    ],
    parameters: [
      { name: "NUM_SPINS", defaultValue: "16", description: "Number of spin sites" },
      { name: "DATA_WIDTH", defaultValue: "16", description: "Fixed-point data width" },
    ],
    code: `module qa_top #(
  parameter NUM_SPINS  = 16,
  parameter DATA_WIDTH = 16
)(
  input  logic        clk, rst_n,
  input  logic [31:0] cfg_data,
  input  logic [7:0]  cfg_addr,
  input  logic        cfg_wr, start,
  output logic        done,
  output logic [31:0] best_energy,
  output logic [63:0] best_spins
);
  // Submodule instantiations
  spin_array   #(.N(NUM_SPINS)) u_spins (...);
  anneal_ctrl  u_ctrl  (.clk, .rst_n, ...);
  config_regs  u_cfg   (.clk, .cfg_data, ...);
  energy_track u_energy(.clk, .rst_n, ...);
endmodule`,
    signalFlow:
      "Config registers → Anneal controller → Spin array ↔ Energy tracker → Best energy/spins output",
  },
  {
    name: "spin_cell",
    description:
      "Individual spin processing element. Computes the local field from neighbor couplings, applies the Metropolis acceptance criterion, and updates the spin state.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "neighbor_spins", direction: "input", width: 8 },
      { name: "couplings", direction: "input", width: 128 },
      { name: "temperature", direction: "input", width: 16 },
      { name: "rng_val", direction: "input", width: 16 },
      { name: "update_en", direction: "input", width: 1 },
      { name: "spin_out", direction: "output", width: 1 },
      { name: "local_field", direction: "output", width: 16 },
    ],
    parameters: [
      { name: "NUM_NEIGHBORS", defaultValue: "8", description: "Max neighbor count" },
      { name: "FP_WIDTH", defaultValue: "16", description: "Fixed-point width" },
    ],
    code: `module spin_cell #(
  parameter NUM_NEIGHBORS = 8,
  parameter FP_WIDTH      = 16
)(
  input  logic                          clk, rst_n,
  input  logic [NUM_NEIGHBORS-1:0]      neighbor_spins,
  input  logic [NUM_NEIGHBORS*FP_WIDTH-1:0] couplings,
  input  logic [FP_WIDTH-1:0]           temperature,
  input  logic [FP_WIDTH-1:0]           rng_val,
  input  logic                          update_en,
  output logic                          spin_out,
  output logic signed [FP_WIDTH-1:0]    local_field
);
  logic signed [FP_WIDTH-1:0] h_local;
  logic signed [FP_WIDTH-1:0] delta_E;
  
  // Compute local field: h = sum(J_ij * s_j)
  always_comb begin
    h_local = '0;
    for (int j = 0; j < NUM_NEIGHBORS; j++)
      h_local += neighbor_spins[j] ? couplings[j*FP_WIDTH +: FP_WIDTH]
                                   : -couplings[j*FP_WIDTH +: FP_WIDTH];
  end

  // Metropolis update
  assign delta_E = spin_out ? (h_local <<< 1) : -(h_local <<< 1);
  
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) spin_out <= 1'b0;
    else if (update_en)
      spin_out <= (delta_E < 0 || rng_val < temperature) ? ~spin_out : spin_out;
      
  assign local_field = h_local;
endmodule`,
    signalFlow:
      "Neighbor spins + couplings → Local field computation → ΔE calculation → Metropolis criterion → Spin update",
  },
  {
    name: "ising_coupler",
    description:
      "Stores and provides coupling coefficients between spin pairs. Implements the J-matrix in hardware using a dual-port BRAM for efficient neighbor lookups.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "wr_en", direction: "input", width: 1 },
      { name: "wr_addr", direction: "input", width: 10 },
      { name: "wr_data", direction: "input", width: 16 },
      { name: "rd_addr_a", direction: "input", width: 10 },
      { name: "rd_addr_b", direction: "input", width: 10 },
      { name: "rd_data_a", direction: "output", width: 16 },
      { name: "rd_data_b", direction: "output", width: 16 },
    ],
    parameters: [
      { name: "DEPTH", defaultValue: "1024", description: "Number of coupling entries" },
      { name: "WIDTH", defaultValue: "16", description: "Coefficient bit width" },
    ],
    code: `module ising_coupler #(
  parameter DEPTH = 1024,
  parameter WIDTH = 16
)(
  input  logic              clk,
  input  logic              wr_en,
  input  logic [$clog2(DEPTH)-1:0] wr_addr,
  input  logic [WIDTH-1:0]  wr_data,
  input  logic [$clog2(DEPTH)-1:0] rd_addr_a, rd_addr_b,
  output logic [WIDTH-1:0]  rd_data_a, rd_data_b
);
  // Dual-port BRAM for J-matrix storage
  logic [WIDTH-1:0] mem [DEPTH];
  
  always_ff @(posedge clk) begin
    if (wr_en) mem[wr_addr] <= wr_data;
    rd_data_a <= mem[rd_addr_a];
    rd_data_b <= mem[rd_addr_b];
  end
endmodule`,
    signalFlow:
      "Write port: config_registers → ising_coupler. Read ports: spin_cell requests → coupling coefficients",
  },
  {
    name: "anneal_controller",
    description:
      "Finite state machine that orchestrates the annealing process. Manages temperature scheduling (linear, exponential, adaptive), iteration counting, and convergence detection.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "start", direction: "input", width: 1 },
      { name: "cfg_t_init", direction: "input", width: 16 },
      { name: "cfg_t_min", direction: "input", width: 16 },
      { name: "cfg_cool_rate", direction: "input", width: 16 },
      { name: "cfg_schedule", direction: "input", width: 2 },
      { name: "cfg_max_steps", direction: "input", width: 32 },
      { name: "current_energy", direction: "input", width: 32 },
      { name: "temperature", direction: "output", width: 16 },
      { name: "update_en", direction: "output", width: 1 },
      { name: "step_count", direction: "output", width: 32 },
      { name: "done", direction: "output", width: 1 },
    ],
    parameters: [
      { name: "FP_WIDTH", defaultValue: "16", description: "Fixed-point width" },
    ],
    code: `module anneal_controller #(
  parameter FP_WIDTH = 16
)(
  input  logic        clk, rst_n, start,
  input  logic [FP_WIDTH-1:0] cfg_t_init, cfg_t_min, cfg_cool_rate,
  input  logic [1:0]  cfg_schedule,  // 00=linear, 01=exp, 10=adaptive
  input  logic [31:0] cfg_max_steps,
  input  logic [31:0] current_energy,
  output logic [FP_WIDTH-1:0] temperature,
  output logic        update_en,
  output logic [31:0] step_count,
  output logic        done
);
  typedef enum logic [1:0] {IDLE, ANNEAL, COOL, DONE} state_t;
  state_t state;
  
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state <= IDLE; temperature <= '0; step_count <= '0;
    end else case (state)
      IDLE:   if (start) begin
                temperature <= cfg_t_init;
                state <= ANNEAL;
              end
      ANNEAL: begin update_en <= 1; state <= COOL; end
      COOL:   begin
                update_en <= 0;
                step_count <= step_count + 1;
                case (cfg_schedule)
                  2'b00: temperature <= temperature - cfg_cool_rate;
                  2'b01: temperature <= temperature - ((temperature * cfg_cool_rate) >> FP_WIDTH);
                  default: temperature <= temperature; // adaptive logic
                endcase
                state <= (temperature <= cfg_t_min || step_count >= cfg_max_steps) ? DONE : ANNEAL;
              end
      DONE:   begin done <= 1; end
    endcase
endmodule`,
    signalFlow:
      "Start signal → FSM (IDLE → ANNEAL → COOL → loop/DONE) → temperature + update_en to spin_array",
  },
  {
    name: "rng_module",
    description:
      "Galois LFSR-based pseudo-random number generator providing uniform random values for the Metropolis acceptance criterion. Uses a configurable polynomial for maximal-length sequences.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "seed", direction: "input", width: 16 },
      { name: "load_seed", direction: "input", width: 1 },
      { name: "rng_out", direction: "output", width: 16 },
    ],
    parameters: [
      { name: "WIDTH", defaultValue: "16", description: "LFSR register width" },
      { name: "POLY", defaultValue: "16'hB400", description: "Feedback polynomial" },
    ],
    code: `module rng_module #(
  parameter WIDTH = 16,
  parameter POLY  = 16'hB400
)(
  input  logic             clk, rst_n,
  input  logic [WIDTH-1:0] seed,
  input  logic             load_seed,
  output logic [WIDTH-1:0] rng_out
);
  logic [WIDTH-1:0] lfsr;
  
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)        lfsr <= {{(WIDTH-1){1'b0}}, 1'b1};
    else if (load_seed) lfsr <= seed;
    else               lfsr <= {lfsr[WIDTH-2:0], 1'b0}
                              ^ (lfsr[WIDTH-1] ? POLY : '0);
  
  assign rng_out = lfsr;
endmodule`,
    signalFlow: "Seed load → LFSR shift → rng_out to each spin_cell for Metropolis comparison",
  },
  {
    name: "spin_array",
    description:
      "Instantiates an array of spin_cell modules and manages the interconnection topology. Handles parallel spin updates and routes neighbor data between cells.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "temperature", direction: "input", width: 16 },
      { name: "update_en", direction: "input", width: 1 },
      { name: "spins_out", direction: "output", width: 64 },
      { name: "total_energy", direction: "output", width: 32 },
    ],
    parameters: [
      { name: "N", defaultValue: "16", description: "Number of spins in the array" },
    ],
    code: `module spin_array #(
  parameter N = 16
)(
  input  logic        clk, rst_n,
  input  logic [15:0] temperature,
  input  logic        update_en,
  output logic [N-1:0] spins_out,
  output logic [31:0] total_energy
);
  logic [15:0] rng_vals [N];
  
  genvar i;
  generate
    for (i = 0; i < N; i++) begin : gen_spins
      rng_module  u_rng  (.clk, .rst_n, .rng_out(rng_vals[i]), ...);
      spin_cell   u_spin (
        .clk, .rst_n,
        .temperature(temperature),
        .rng_val(rng_vals[i]),
        .update_en(update_en),
        .spin_out(spins_out[i]),
        ...
      );
    end
  endgenerate
endmodule`,
    signalFlow:
      "Temperature + update_en → each spin_cell. RNG → spin_cell. Neighbor topology wired between cells.",
  },
  {
    name: "config_registers",
    description:
      "Memory-mapped configuration register file. Stores all tunable parameters: initial temperature, cooling rate, schedule type, coupling coefficients, and max iteration count.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "cfg_addr", direction: "input", width: 8 },
      { name: "cfg_data", direction: "input", width: 32 },
      { name: "cfg_wr", direction: "input", width: 1 },
      { name: "t_init", direction: "output", width: 16 },
      { name: "t_min", direction: "output", width: 16 },
      { name: "cool_rate", direction: "output", width: 16 },
      { name: "schedule", direction: "output", width: 2 },
      { name: "max_steps", direction: "output", width: 32 },
    ],
    parameters: [
      { name: "NUM_REGS", defaultValue: "16", description: "Number of config registers" },
    ],
    code: `module config_registers #(
  parameter NUM_REGS = 16
)(
  input  logic        clk,
  input  logic [7:0]  cfg_addr,
  input  logic [31:0] cfg_data,
  input  logic        cfg_wr,
  output logic [15:0] t_init, t_min, cool_rate,
  output logic [1:0]  schedule,
  output logic [31:0] max_steps
);
  logic [31:0] regs [NUM_REGS];
  
  always_ff @(posedge clk)
    if (cfg_wr && cfg_addr < NUM_REGS)
      regs[cfg_addr] <= cfg_data;
  
  assign t_init    = regs[0][15:0];
  assign t_min     = regs[1][15:0];
  assign cool_rate = regs[2][15:0];
  assign schedule  = regs[3][1:0];
  assign max_steps = regs[4];
endmodule`,
    signalFlow:
      "AXI/cfg bus writes → register file → parameter outputs to anneal_controller and spin_array",
  },
  {
    name: "energy_tracker",
    description:
      "Monitors the total system energy across annealing steps. Tracks the best (lowest) energy found and stores the corresponding spin configuration for final readout.",
    ports: [
      { name: "clk", direction: "input", width: 1 },
      { name: "rst_n", direction: "input", width: 1 },
      { name: "current_energy", direction: "input", width: 32 },
      { name: "current_spins", direction: "input", width: 64 },
      { name: "sample_en", direction: "input", width: 1 },
      { name: "best_energy", direction: "output", width: 32 },
      { name: "best_spins", direction: "output", width: 64 },
    ],
    parameters: [],
    code: `module energy_tracker (
  input  logic        clk, rst_n,
  input  logic [31:0] current_energy,
  input  logic [63:0] current_spins,
  input  logic        sample_en,
  output logic [31:0] best_energy,
  output logic [63:0] best_spins
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      best_energy <= 32'h7FFF_FFFF; // max positive
      best_spins  <= '0;
    end else if (sample_en && $signed(current_energy) < $signed(best_energy)) begin
      best_energy <= current_energy;
      best_spins  <= current_spins;
    end
endmodule`,
    signalFlow:
      "Spin array energy → comparator → update best if lower → output best_energy and best_spins",
  },
];
