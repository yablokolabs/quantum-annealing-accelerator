# Xilinx Vivado constraints (example for Artix-7)
# Adjust for your target FPGA board

# Clock constraint — 100 MHz
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Input delay
set_input_delay -clock sys_clk -max 2.0 [all_inputs]
set_input_delay -clock sys_clk -min 0.5 [all_inputs]

# Output delay
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.5 [all_outputs]

# Reset is async — mark as false path for timing
set_false_path -from [get_ports rst_n]
