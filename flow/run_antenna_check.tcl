# OpenROAD antenna + placement DRC signoff
# Reads DEF and runs check_antennas + check_placement
set PDK /usr/local/share/pdk/sky130A

read_lef $PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef $PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_def SHA256_15ns.def

# 16-3: Antenna check
puts ""
puts "============================================"
puts "Antenna Check (16-3)"
puts "============================================"
check_antennas -verbose -report_violating_nets -report_file SHA256_15ns_antenna_signoff.rpt

# 16-4: Placement DRC check
puts ""
puts "============================================"
puts "Placement DRC Check (16-4)"
puts "============================================"
check_placement -verbose

puts ""
puts "Signoff checks complete."
exit
