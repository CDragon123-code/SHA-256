# Magic LVS-mode SPICE Extraction (16-2 Step 1, retry)
# Uses ext2spice lvs to get LVS-friendly output
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

# Configure SPICE output for LVS
# - hierarchy on: keep hierarchy
# - subcircuits descend: expand subcircuits to transistor level
# - format ngspice: use ngspice format
# - cthresh/rthresh: disable parasitics (LVS mode)
ext2spice hierarchy on
ext2spice subcircuits descend on
ext2spice format ngspice
ext2spice cthresh infinite
ext2spice rthresh infinite
ext2spice lvs
ext2spice -o SHA256_15ns_lvs.spice

puts ""
puts "============================================"
puts "LVS-mode SPICE extraction complete"
puts "============================================"
puts "Output: SHA256_15ns_lvs.spice"
