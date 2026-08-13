#!/usr/bin/env python3
"""Post-process Magic-extracted SPICE to use library SPICE subckt definitions.

Problem: Magic extraction exposes internal nodes (e.g., a_27_47#) as subckt ports,
causing port count mismatch with the library SPICE definitions.

Solution:
1. Strip all stdcell .subckt definitions from layout SPICE (keep only SHA256 top cell)
2. Add .INCLUDE of the library SPICE file
3. Fix X-instance calls: trim extra internal nets to match library port count
4. Merge multi-line X-instances into single lines
"""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'SHA256_15ns_transistor_nopar.spice')
DST = os.path.join(HERE, 'SHA256_15ns_transistor_lib.spice')
LIB_SPICE = '/usr/local/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice'

# Step 1: Build port map from library SPICE
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

print(f'Library has {len(lib_ports)} subckt definitions')

# Step 2: Read layout SPICE
with open(SRC, 'r', encoding='utf-8', errors='replace') as f:
    lines = f.readlines()

# Step 3: Strip stdcell subckt definitions (keep only SHA256)
output = []
in_subckt = False
depth = 0
is_stdcell = False
stripped_subckts = 0

for line in lines:
    s = line.strip()
    if (s.startswith('.subckt') or s.startswith('.SUBCKT')) and not in_subckt:
        parts = s.split()
        if len(parts) >= 2:
            cellname = parts[1]
            if cellname == 'SHA256':
                in_subckt = True
                depth = 1
                is_stdcell = False
                output.append(line)
            else:
                in_subckt = True
                depth = 1
                is_stdcell = True
                stripped_subckts += 1
    elif in_subckt:
        if s.startswith('.subckt') or s.startswith('.SUBCKT'):
            depth += 1
            if not is_stdcell:
                output.append(line)
        elif s.startswith('.ends') or s.startswith('.ENDS'):
            depth -= 1
            if depth <= 0:
                in_subckt = False
            if not is_stdcell:
                output.append(line)
        else:
            if not is_stdcell:
                output.append(line)
    else:
        output.append(line)

print(f'Stripped {stripped_subckts} stdcell subckt definitions')

# Step 4: Add .INCLUDE at the beginning (after comment block)
include_line = f'.INCLUDE "{LIB_SPICE}"\n'
insert_idx = 0
for i, line in enumerate(output):
    if not line.strip().startswith('*') and line.strip():
        insert_idx = i
        break
output.insert(insert_idx, include_line)

# Step 5: Fix X-instance calls - merge multi-line and trim extra internal nets
fixed_output = []
fixed_count = 0
merged_count = 0
i = 0
while i < len(output):
    line = output[i]
    s = line.strip()

    if re.match(r'^X\S+', s) and not s.startswith('.'):
        # Collect full instance (including continuation lines)
        full_parts = list(s.split())
        has_continuation = False
        while i + 1 < len(output) and output[i + 1].strip().startswith('+'):
            i += 1
            has_continuation = True
            cont_parts = output[i].strip()[1:].split()
            full_parts.extend(cont_parts)

        if len(full_parts) >= 2:
            cellname = full_parts[-1]
            inst_name = full_parts[0]
            nets = full_parts[1:-1]

            if cellname in lib_ports:
                expected_ports = len(lib_ports[cellname])
                if len(nets) > expected_ports:
                    # Trim extra nets (internal nodes)
                    nets = nets[:expected_ports]
                    fixed_count += 1
                # Always rebuild as single line (merge continuation)
                if has_continuation:
                    merged_count += 1
                new_line = inst_name + ' ' + ' '.join(nets) + ' ' + cellname + '\n'
                fixed_output.append(new_line)
                i += 1
                continue
            else:
                # Unknown cell - keep as-is but merge continuation
                if has_continuation:
                    merged_count += 1
                    new_line = inst_name + ' ' + ' '.join(nets) + ' ' + cellname + '\n'
                    fixed_output.append(new_line)
                    i += 1
                    continue

        # Default: keep original line
        fixed_output.append(line)
    else:
        fixed_output.append(line)
    i += 1

print(f'Fixed {fixed_count} X-instance calls (trimmed internal nets)')
print(f'Merged {merged_count} multi-line X-instances')

with open(DST, 'w', encoding='utf-8') as f:
    f.writelines(fixed_output)

print(f'Created {DST}')
print(f'Original lines: {len(lines)}, Output lines: {len(fixed_output)}')
