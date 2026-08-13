# Magic Transistor-Level SPICE Extraction Script (16-2 Step 1)
# Reads DEF, extracts transistor-level SPICE for LVS
# PDK_ROOT must be set to /usr/local/share/pdk

crashbackups stop
drc off
snap internal

# Read LEF for std cell definitions
lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# Read GDS for std cell layouts (needed for transistor extraction)
gds flatglob *__example_*
gds flatten true
gds read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds

# Read DEF
def read SHA256_15ns.def

# Load the top cell
load SHA256
select top cell
expand

# Extract transistor-level SPICE
extract do local
extract no all
extract all

# Configure SPICE output
ext2spice hierarchy on
ext2spice subcircuits on
ext2spice format ngspice
ext2spice cthresh 0
ext2spice rthresh 0
ext2spice -o SHA256_15ns_transistor.spice

puts ""
puts "============================================"
puts "Transistor-level SPICE extraction complete"
puts "============================================"
puts "Output: SHA256_15ns_transistor.spice"
