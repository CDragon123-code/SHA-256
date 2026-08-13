# SDC for Caravel user_project_wrapper with SHA-256 accelerator
# Clock: 15ns (66.7MHz) — matches 方案 B timing closure

set_units -time ns -capacitance pF -resistance kohm -voltage V -current mA

create_clock [get_ports wb_clk_i] -name wb_clock -period 15.0
set_clock_uncertainty 0.5 [get_clocks wb_clock]

# Wishbone bus I/O delays
set_input_delay  -clock wb_clock -max 2.0 [get_ports {wb_rst_i wbs_stb_i wbs_cyc_i wbs_we_i wbs_sel_i[*] wbs_dat_i[*] wbs_adr_i[*]}]
set_input_delay  -clock wb_clock -min 0.0 [get_ports {wb_rst_i wbs_stb_i wbs_cyc_i wbs_we_i wbs_sel_i[*] wbs_dat_i[*] wbs_adr_i[*]}]
set_output_delay -clock wb_clock -max 2.0 [get_ports {wbs_ack_o wbs_dat_o[*]}]
set_output_delay -clock wb_clock -min 0.0 [get_ports {wbs_ack_o wbs_dat_o[*]}]

# Logic analyzer pins (unused, but constrained for Caravel compliance)
set_input_delay  -clock wb_clock -max 2.0 [get_ports {la_data_in[*] la_oenb la_iena}]
set_output_delay -clock wb_clock -max 2.0 [get_ports {la_data_out[*]}]

# User outputs
set_output_delay -clock wb_clock -max 2.0 [get_ports {user_clock2 user_irq[*] irq[*]}]

# False path on GPIO (bidirectional, not timing-critical for SHA256)
set_false_path -from [get_ports io[*]]
set_false_path -to   [get_ports io[*]]
