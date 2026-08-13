# Netgen Transistor-Level LVS Script (16-2)
# Run with: netgen -noconsole < run_transistor_lvs.tcl
# Uses 'filename cellname' syntax to ensure correct circuit identification

lvs "/tmp/lvs_layout/SHA256 SHA256" "/tmp/lvs_schematic/SHA256 SHA256" /usr/local/share/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl SHA256_15ns_transistor_lvs.report

puts ""
puts "============================================"
puts "Transistor-Level LVS Complete"
puts "============================================"
puts "Report: SHA256_15ns_transistor_lvs.report"
quit
