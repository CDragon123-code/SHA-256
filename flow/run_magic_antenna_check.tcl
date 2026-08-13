# Magic Antenna Check Script (16-3 independent verification)
# Reads DEF and runs Magic's antennacheck command
# PDK_ROOT must be set to /usr/local/share/pdk

crashbackups stop
drc off
snap internal

# Read LEF for std cell definitions
lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# Read GDS for std cell layouts
gds flatglob *__example_*
gds flatten true
gds read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds

# Read DEF
def read SHA256_15ns.def

# Load the top cell
load SHA256
select top cell
expand

# Run antenna check
extract do local
extract no all
extract all
antennacheck

puts ""
puts "============================================"
puts "Magic Antenna Check Complete"
puts "============================================"
