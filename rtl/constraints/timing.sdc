# Intel Quartus SDC constraints (example)
# Adjust for your target FPGA board

# Clock constraint — 100 MHz
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

# Input constraints
set_input_delay -clock sys_clk -max 2.0 [get_ports {rst_n}]
set_input_delay -clock sys_clk -max 2.0 [get_ports {host_*}]

# Output constraints
set_output_delay -clock sys_clk -max 2.0 [get_ports {final_spins[*]}]
set_output_delay -clock sys_clk -max 2.0 [get_ports {done}]

# Async reset
set_false_path -from [get_ports {rst_n}]
