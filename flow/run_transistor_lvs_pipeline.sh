#!/bin/bash
# Transistor-level LVS pipeline for updated 15ns DEF
# Runs: Magic extraction → strip parasitics → fix subckts → rename nets → Netgen LVS

set -e
cd /home/openroad/SHA-256/flow
export PDK_ROOT=/usr/local/share/pdk

echo "============================================================"
echo "Step 1: Magic SPICE extraction from updated DEF"
echo "============================================================"
magic -noconsole -dnull -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc <<'MAGIC_EOF'
crashbackups stop
drc off
snap internal

lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

gds flatglob *__example_*
gds flatten true
gds read $env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds

def read SHA256_15ns.def

load SHA256
select top cell
expand

extract do local
extract no all
extract all

ext2spice hierarchy on
ext2spice subcircuits on
ext2spice format ngspice
ext2spice cthresh 0
ext2spice rthresh 0
ext2spice -o SHA256_15ns_transistor.spice

puts "Extraction complete: SHA256_15ns_transistor.spice"
MAGIC_EOF

echo "============================================================"
echo "Step 2: Strip parasitics + physical cells"
echo "============================================================"
python3 strip_parasitics.py

echo "============================================================"
echo "Step 3: Fix layout subckts (use library SPICE)"
echo "============================================================"
python3 fix_layout_subckts.py

echo "============================================================"
echo "Step 4: Rename CTS load nets"
echo "============================================================"
python3 rename_clkload_nets.py

echo "============================================================"
echo "Step 5: Generate transistor-level schematic CDL"
echo "============================================================"
# Copy v6pos schematic and change .INCLUDE from CDL to SPICE library
python3 -c "
import re
with open('SHA256_15ns.schematic.v6pos.cdl', 'r') as f:
    content = f.read()
# Replace CDL include with SPICE include
content = re.sub(
    r'\.INCLUDE.*sky130_fd_sc_hd\.cdl.*',
    '.INCLUDE \"/usr/local/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice\"',
    content
)
with open('SHA256_15ns_schematic_transistor.cdl', 'w') as f:
    f.write(content)
print('Generated SHA256_15ns_schematic_transistor.cdl')
"

echo "============================================================"
echo "Step 6: Setup files for Netgen"
echo "============================================================"
# Create symlinks with no extension so cell name matches
mkdir -p /tmp/lvs_layout /tmp/lvs_schematic
cp SHA256_15ns_transistor_lib_fixed.spice /tmp/lvs_layout/SHA256
cp SHA256_15ns_schematic_transistor.cdl /tmp/lvs_schematic/SHA256

echo "============================================================"
echo "Step 7: Run Netgen transistor-level LVS"
echo "============================================================"
netgen -noconsole < run_transistor_lvs.tcl 2>&1 | tail -20

echo "============================================================"
echo "Pipeline complete!"
echo "Report: SHA256_15ns_transistor_lvs.report"
echo "============================================================"
