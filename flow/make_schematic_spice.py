#!/usr/bin/env python3
"""Create schematic CDL that uses SPICE library (X-devices with sky130_fd_pr__ prefix)
instead of CDL library (M-devices with short names).
This makes both layout and schematic sides use the same transistor format.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'SHA256_15ns.schematic.v6pos.cdl')
DST = os.path.join(HERE, 'SHA256_15ns_schematic_transistor.cdl')

OLD_INCLUDE = '/usr/local/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl'
NEW_INCLUDE = '/usr/local/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice'

with open(SRC, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

content = content.replace(OLD_INCLUDE, NEW_INCLUDE)

with open(DST, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Created {DST}')
print(f'Include: {NEW_INCLUDE}')
