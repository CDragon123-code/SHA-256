#!/bin/bash
# ============================================================================
# LVS v5: Fix TOP-LEVEL PIN mismatch between layout SPICE (flat, data[N])
#         and schematic CDL (packed data bus + VPWR/VGND explicit pins)
#
# Root cause from v4 report:
#   Layout pins: clk, rst, soc, rd, eoc, data[0]..data[31]  (37 total)
#   Schem  pins: clk, rd,  rst, soc, eoc, data(1 bus), VPWR, VGND
# Result: "Top level cell failed pin matching" even though:
#   - Device classes SHA256 and SHA256 are equivalent ✅
#   - 70,205 MOS transistors match exactly                ✅
#
# v5 Fix: rewrite schem CDL top SUBCKT pin list to match layout
# ============================================================================
set -e
cd /home/openroad/SHA-256/flow

SCHEM_V4=SHA256_schematic_libcdl_aligned.cdl
SCHEM_V5=SHA256_schematic_v5_pinsfixed.cdl
LAYOUT=SHA256_layout_stripped_nopar.spice
SETUP=/usr/local/share/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl
REPORT=SHA256.netgen_lvs.v5.report

echo "[LVS v5] Step 1: Build new 37-pin SUBCKT line (match DEF pin names)"
# DEF pin order: clk, data[0..31], eoc, rd, rst, soc (but Netgen matches by NAME not position)
NEWPINLIST="clk rst soc rd eoc"
for i in $(seq 0 31); do
  NEWPINLIST="$NEWPINLIST data[$i]"
done
echo "  New pin list (37 pins): $(echo $NEWPINLIST | wc -w)"
echo "  SUBCKT line: .SUBCKT SHA256 $NEWPINLIST"

echo "[LVS v5] Step 2: Rewrite schem CDL -> v5  (replace ONLY 1 line at 1805794)"
python3 - <<PYEOF
src = "$SCHEM_V4"
dst = "$SCHEM_V5"
new_pins = """$NEWPINLIST"""
new_subckt = ".SUBCKT SHA256 " + new_pins
with open(src, "r", encoding="latin-1", errors="replace") as f:
    lines = f.readlines()
# Line number in report was 1805794 (1-indexed) — but file may have shifted; scan for it
changed = 0
for i, line in enumerate(lines):
    if line.startswith(".SUBCKT SHA256 clk rd rst soc eoc data VPWR VGND"):
        lines[i] = new_subckt + "\n"
        changed += 1
        print(f"  Changed line {i+1}: {line.rstrip()}")
        print(f"           ->  {new_subckt}")
with open(dst, "w", encoding="latin-1", errors="replace") as f:
    f.writelines(lines)
print(f"  Changed {changed} line(s). Wrote {dst}")
PYEOF

echo "[LVS v5] Step 3: Verify v5 SHA256 SUBCKT in schem CDL"
grep -n '.SUBCKT SHA256' $SCHEM_V5
echo "  - Expected: 37 pins (clk/rst/soc/rd/eoc + data[0..31]), NO VPWR/VGND"

echo "[LVS v5] Step 4: Layout SPICE stays as-is (flat — Netgen treats it as top-level SHA256 with 37 DEF-named pins)"
echo "  Layout pins (Netgen extracted from flat netlist should match DEF 37 pins)"

echo "[LVS v5] Step 5: Run Netgen batch LVS (blackbox stdcells via sky130A_setup.tcl permutations)"
echo "  netgen -batch lvs \"$LAYOUT SHA256\" \"$SCHEM_V5 SHA256\" \"$SETUP\" \"$REPORT\""
echo "  Estimated time: 5-10 min (70k MOS, ~34k nets after flatten)"
START=$(date +%s)
netgen -batch lvs \
  "$LAYOUT SHA256" \
  "$SCHEM_V5 SHA256" \
  "$SETUP" \
  "$REPORT" 2>&1 | tail -n 30
DUR=$(( $(date +%s) - START ))
echo ""
echo "[LVS v5] Step 6: Extract final result from $REPORT"
echo "================================================================"
grep -nE 'Final result|Circuits match|Netlists match|Device classes|failed pin matching|PASS|FAIL' "$REPORT" | tail -n 15
echo "================================================================"
echo "[LVS v5] Done. Duration: ${DUR}s. Full report at: $REPORT ($(wc -c < "$REPORT") bytes)"
