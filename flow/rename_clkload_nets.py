#!/usr/bin/env python3
"""Rename clkload output nets in layout SPICE to match schematic convention.

Problem: CTS load buffers (clkload*) have floating outputs.
- Schematic: outputs named 'Y' or 'X' (pin name, shared across instances)
- Layout: outputs named 'clkload90/X', 'clkload80/X' (unique per instance)

This causes 149 net mismatches in LVS because Netgen sees different net topologies.

Solution: Rename clkload output nets in layout to use the cell's output port name
(e.g., 'clkload90/X' -> 'X', 'clkload91/Y' -> 'Y').
This merges floating outputs the same way the schematic does.
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'SHA256_15ns_transistor_lib.spice')
DST = os.path.join(HERE, 'SHA256_15ns_transistor_lib_fixed.spice')

# Read the layout SPICE
with open(SRC, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

# Find all clkload output nets: pattern is clkload<NUM>/<PORT>
# These appear as net names in X-instance lines
# Rename them to just <PORT> (the port name without the clkload prefix)

# Pattern: clkload<digits>/<OUTPUT_PORT>
# Only rename OUTPUT nets (X or Y), NOT input nets (A, B, etc.)
# e.g., clkload90/X -> X, clkload91/Y -> Y, clkload80/X -> X
# But keep clkload90/A as-is (it's a unique input net)
pattern = re.compile(r'\bclkload\d+/([XY])\b')

# Count replacements
count = 0
def replacer(m):
    global count
    count += 1
    return m.group(1)

new_content = pattern.sub(replacer, content)

with open(DST, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f'Created {DST}')
print(f'Renamed {count} clkload net references')
