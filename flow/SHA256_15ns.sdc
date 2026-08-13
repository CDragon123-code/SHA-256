set_units -time ns -capacitance pF -resistance kohm -voltage V -current mA
create_clock [get_ports clk] -name core_clock -period 15.0
set_input_delay  -clock core_clock -max 1.0 [get_ports {data_in rst soc rd}]
set_input_delay  -clock core_clock -min 0.0 [get_ports {data_in rst soc rd}]
set_output_delay -clock core_clock -max 1.0 [get_ports {eoc data_out data_oe}]
set_output_delay -clock core_clock -min 0.0 [get_ports {eoc data_out data_oe}]
