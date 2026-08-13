# OpenROAD Power Grid Check Script (16-5)
# Checks power grid integrity for VDD and VSS nets

set PDK /usr/local/share/pdk/sky130A

# Read LEF
read_lef $PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# Read DEF
read_def SHA256_15ns.def

# Check power grid
puts "============================================"
puts "Power Grid Check (16-5)"
puts "============================================"

# Check VDD (power) grid
check_power_grid -net VDD -error_file SHA256_15ns_pwr_error.rpt

# Check VSS (ground) grid
check_power_grid -net VSS -error_file SHA256_15ns_gnd_error.rpt

puts ""
puts "============================================"
puts "Power Grid Check Complete"
puts "============================================"
puts "Power errors: SHA256_15ns_pwr_error.rpt"
puts "Ground errors: SHA256_15ns_gnd_error.rpt"
