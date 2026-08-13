#!/usr/bin/env python3
"""Fix pin order and net names in layout SPICE to match schematic CDL.

Problem: Magic extraction uses a different pin order than the library SPICE.
For example, sky130_fd_sc_hd__clkbuf_4:
  Magic:   X A VGND VPWR VPB VNB
  Library: A VGND VNB VPB VPWR X

The existing fix_layout_subckts.py only trims excess nets but doesn't reorder.
This causes 19 net mismatches in transistor-level LVS.

Solution:
1. Read Magic extraction pin order from original .subckt definitions
2. Read library SPICE pin order
3. For each X-instance, reorder nets from Magic order to library order
4. Normalize PG net names (VSUBS->VGND, wire9/VPB->VPWR, etc.)
5. Compare with schematic CDL to create net name mapping
6. Rename layout nets to match schematic nets
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LAYOUT_IN = os.path.join(HERE, 'SHA256_15ns_transistor_lib_fixed.spice')
LAYOUT_OUT = os.path.join(HERE, 'SHA256_15ns_transistor_lvs_ready.spice')
SCHEMATIC = os.path.join(HERE, 'SHA256_15ns_schematic_transistor.cdl')
MAGIC_EXTRACTION = os.path.join(HERE, 'SHA256_15ns_transistor_nopar.spice')
LIB_SPICE = '/usr/local/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice'

# Step 1: Read library SPICE pin order
print("Step 1: Reading library SPICE pin order...")
lib_ports = {}
with open(LIB_SPICE, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        s = line.strip()
        if s.startswith('.subckt') or s.startswith('.SUBCKT'):
            parts = s.split()
            if len(parts) >= 2:
                cellname = parts[1]
                ports = parts[2:]
                lib_ports[cellname] = ports
print(f"  Library has {len(lib_ports)} subckt definitions")

# Step 2: Read Magic extraction pin order
print("Step 2: Reading Magic extraction pin order...")
magic_ports = {}
with open(MAGIC_EXTRACTION, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        s = line.strip()
        if s.startswith('.subckt') or s.startswith('.SUBCKT'):
            parts = s.split()
            if len(parts) >= 2:
                cellname = parts[1]
                ports = parts[2:]
                magic_ports[cellname] = ports
print(f"  Magic extraction has {len(magic_ports)} subckt definitions")

# Step 3: Build permutation mapping for each cell
print("Step 3: Building pin order permutations...")
perm_map = {}  # cellname -> list of indices to reorder
for cellname, lib_pins in lib_ports.items():
    if cellname in magic_ports:
        magic_pins = magic_ports[cellname]
        if len(magic_pins) == len(lib_pins):
            # Create permutation: for each library pin position, find its position in magic
            perm = []
            for lib_pin in lib_pins:
                if lib_pin in magic_pins:
                    perm.append(magic_pins.index(lib_pin))
                else:
                    perm.append(None)
            if None not in perm:
                perm_map[cellname] = perm
print(f"  Built permutations for {len(perm_map)} cell types")

# Step 4: Read schematic CDL to build instance -> nets mapping
print("Step 4: Reading schematic CDL for net name mapping...")
schem_instances = {}  # inst_name -> (nets, cellname)
with open(SCHEMATIC, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        s = line.strip()
        if re.match(r'^X\S+', s) and not s.startswith('.'):
            parts = s.split()
            if len(parts) >= 2:
                inst_name = parts[0]
                cellname = parts[-1]
                nets = parts[1:-1]
                schem_instances[inst_name] = (nets, cellname)
print(f"  Read {len(schem_instances)} schematic instances")

# Step 5: Process layout SPICE
print("Step 5: Processing layout SPICE...")
with open(LAYOUT_IN, 'r', encoding='utf-8', errors='replace') as f:
    lines = f.readlines()

# Build net name mapping: layout_name -> schematic_name
net_mapping = {}
reordered_count = 0
mapped_count = 0
output_lines = []

for line in lines:
    s = line.strip()

    if re.match(r'^X\S+', s) and not s.startswith('.'):
        parts = s.split()
        if len(parts) >= 2:
            inst_name = parts[0]
            cellname = parts[-1]
            nets = parts[1:-1]

            # Reorder pins if we have a permutation for this cell
            if cellname in perm_map:
                perm = perm_map[cellname]
                if len(nets) == len(perm):
                    new_nets = [nets[i] for i in perm]
                    if new_nets != nets:
                        reordered_count += 1
                    nets = new_nets

            # Compare with schematic to build net mapping
            if inst_name in schem_instances:
                schem_nets, schem_cellname = schem_instances[inst_name]
                if cellname == schem_cellname and len(nets) == len(schem_nets):
                    for layout_net, schem_net in zip(nets, schem_nets):
                        if layout_net != schem_net:
                            if layout_net not in net_mapping:
                                net_mapping[layout_net] = schem_net
                                mapped_count += 1

            # Rebuild the line with reordered nets
            new_line = inst_name + ' ' + ' '.join(nets) + ' ' + cellname + '\n'
            output_lines.append(new_line)
        else:
            output_lines.append(line)
    else:
        output_lines.append(line)

print(f"  Reordered {reordered_count} X-instances")
print(f"  Created {mapped_count} net name mappings")

# Step 6: Apply net name mapping to the entire file
print("Step 6: Applying net name mapping...")
# Sort mappings by length (longest first) to avoid partial replacements
sorted_mappings = sorted(net_mapping.items(), key=lambda x: len(x[0]), reverse=True)

final_lines = []
replaced_count = 0
for line in output_lines:
    new_line = line
    for old_net, new_net in sorted_mappings:
        if old_net in new_line:
            # Use word boundary to avoid partial replacements
            new_line = re.sub(r'\b' + re.escape(old_net) + r'\b', new_net, new_line)
            replaced_count += 1
    final_lines.append(new_line)

print(f"  Applied {replaced_count} net replacements")

with open(LAYOUT_OUT, 'w', encoding='utf-8') as f:
    f.writelines(final_lines)

print(f"\nOutput: {LAYOUT_OUT}")
print(f"Original lines: {len(lines)}, Output lines: {len(final_lines)}")

# Summary of mappings
print(f"\n=== Net name mappings (first 30) ===")
for old_net, new_net in list(sorted_mappings)[:30]:
    print(f"  {old_net} -> {new_net}")
